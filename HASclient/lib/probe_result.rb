class ProbeResult
#require 'mongo'
#include Mongo
#written by Arslan
#adding mongo DB connection~AR
	#require 'mongo'
	#include Mongo
#connect to the "qoemonitor" database
#db = Connection.new.db('qoemonitor')
#db = Mongo::Connection.new("localhost").db("qoemonitor")
#client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'qoemonitor', :connect=> :direct, :user=> 'arslan', :password=> '1234')
#client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'qoemonitor', user:'arslan', password: '1234', auth_mech: :mongodb_cr)
#@ip_add=request.remote_ip
# wrapper to send data to the server
def data_to_server
client = Mongo::Client.new([ '127.0.0.1:27017' ], :database => 'qoemonitor')
artists = client[:qoe]
#ip_add=request.remote_ip
new_post = { :stalling_event => "#{@stalling_events}",
:stalling_event_time => "#{@stalling_events_time}",
:stalling_events_duration => "#{@stalling_events_duration}",
:total_stalling_duration => "#{@total_stalling_duration}",
:average_stalling_duration=> "#{@average_stalling_duration}"
}
post_id = client[:qoe].insert_one(new_post)
end 


#post_id = client[:qoe].insert_one({:name => 'arslan'})
  #artists.with(:read => { :mode => :primary_preferred }).find.to_a
  #artists.with(:write => { :w => :3 }).insert_one( { :name => 'Depeche Mode' } )
#db=client.database
#authenticate the user of the database
#auth = db.authenticate(arslan, 1234)
#get an access to "qoe" collection  
#posts = client[:qoe]
   # Initialize result. You can pass an argument hash
  def initialize(args = {})
    @probe_ip = nil
    @probe_id = nil
    @error    = nil
    @service  = nil
    @player   = nil
    @video_id = nil

    args.each do |k,v|
      instance_variable_set("@#{k}", v) unless v.nil?
    end

    # general data
    @date = Time.new

    # video metadata
    @resolutions    = []
    @video_duration = nil

    # stalling related
    @player_load_time           = nil
    @startup_delay              = nil
    @stalling_events           = 0
    @stalling_events_duration  = []
    @stalling_events_time      = []
    @total_stalling_duration   = 0
    @average_stalling_duration = 0

    # quality related
    @quality_events_time  = []
    @quality_events_level = []

    # keep timestamps
    @events = []
  end

  # Extracts a console message as long as it's for the probe.
  # The message needs to be a Hash parsed from a JSON response
  def extract_message(msg)
    case msg['event']
    when "playerStateChange", "playerQualityChange", "playerReady", "pageLoaded"
      @events << ProbeEvent.new(msg['event'], msg['timestamp'], msg['data'])
    when "videoDuration"
      @video_duration = msg['data'].to_i
    when "finished"
      calculate_results
      # TODO what to do with the probe?
      # close the page?
    end
  end

  # Wrapper for calculating results of the probe run.
  def calculate_results
    Logger.info "Probing finished. Calculating results."
    calculate_startup_time
    calculate_results_stalling
    calculate_results_switching
    print_results

#####Modified by Arslan ----sends the results in the db 
data_to_server

    # TODO what to do with the results?
  end

  # Calculate the time for the player to load, relative to page load time,
  # and the time the player takes to start (which is basically the first stalling time)
  def calculate_startup_time
    @player_load_time = @events.find { |e| e.type == "playerReady" }.timestamp - @events.find { |e| e.type == "pageLoaded" }.timestamp
    @startup_delay    = @events.find { |e| e.type == "playerStateChange" and e.data == "playing" }.timestamp - @events.find { |e| e.type == "playerReady" }.timestamp
  end

  # Calculate stalling events. This creates a list of stalling event starts, and their durations.
  # Consecutive "stalling" messages can occur when there is a pause inbetween -- this is counted as
  # a single stalling event though, taking the first timestamp.
  def calculate_results_stalling
    state               = nil
    stalling_start_time = nil
    stalling_end_time   = nil

    @events.each do |event|
      next if event.type != "playerStateChange"
      next unless ['stalling', 'playing'].include? event.data

      if event.data == "stalling"
        if state == "playing" or state.nil? # if we didn't buffer already
          stalling_start_time = event.timestamp
        end
        state = "stalling"
        next
      end

      if state == "stalling" and event.data == "playing"
        state = "playing"
        stalling_end_time = event.timestamp

        # we found a stalling event
        @stalling_events += 1
        @stalling_events_time      << stalling_start_time
        @stalling_events_duration  << (stalling_end_time - stalling_start_time)
        @total_stalling_duration   += @stalling_events_duration.last
        @average_stalling_duration = @stalling_events_duration.reduce(:+).to_f / @stalling_events_duration.size
#post_id = client[:qoe].insert_one({:name => 'arslan'})
#post_id = client[:qoe].insert_one({:name => 'arslan'})
      end
    end
  end

#function to send the data to mongodb, qoemonitor db in qoe collection
#def write_data_in_mongo
#if (@stalling_events.instance_value=>2)
#new_post = { :stalling_event => "#{@stalling_events}",
#:stalling_event_time => "#{@stalling_events_time}",
#:stalling_events_duration => "#{@stalling_events_duration}",
#:total_stalling_duration => "#{@total_stalling_duration}",
#:average_stalling_duration=> "#{@average_stalling_duration}",
#}
#post_id = client[:qoe].insert_one(new_post)
#end
#end  

#post_id = client[:qoe].insert_one({:name => 'arslan'})
  # Calculate the results for switching times. This just assigns start timestamps and quality events,
  # not considering any stalling etc. If there is no quality adaptation, the probe needs to just send
  # a single playerQualityChange event at the start.
  def calculate_results_switching
    @events.select { |e| e.type == "playerQualityChange" }.each do |event|
      @quality_events_time << event.timestamp
      @quality_events_level << event.data
    end
  end

  # Print results
  def print_results

    puts
    puts "PROBE RESULTS"
    puts "-----------------------------------------------------"
    puts
    puts "Player load time: #{@player_load_time} ms"
    puts "Startup delay:    #{@startup_delay} ms"
    puts "Video duration:   #{@video_duration} seconds"
    puts
    puts "Stalling duration (avg): #{@average_stalling_duration}"
    puts "Stalling events:"
    @stalling_events_time.zip(@stalling_events_duration).each { |time, dur| puts " - #{time}, #{dur}" }
    #puts
    #puts "Quality switches:"
    #@quality_events_time.zip(@quality_events_level).each { |time, lv| puts " - #{time}, #{lv}" }
  end
#post_id = client[:qoe].insert_one({:name => 'arslan'})
end
