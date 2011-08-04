require 'json'

class BoothController < ApplicationController
  
  PHOTO_COUNT = 4 # number of photos that will be taken
  PHOTO_PREDELAY = 4 # delay before first photo is taken
  PHOTO_DELAY = 12 # delay between photos being taken
  
  def show
  end

  # Indicates the client is ready to begin taking photos.
  # Returns a set of timestamps the camera will click at.
  def start_snap
    @response = {}
    @response[:timestamps] = []
    start_time = (Time.now.to_i + PHOTO_PREDELAY) * 1000
    PHOTO_COUNT.times do |i|
      @response[:timestamps] << start_time + (PHOTO_DELAY * 1000 * i)
    end

    @pset = PhotoSet.create
    
    @response[:set_id] = @pset.id

    @response[:timestamps].each_with_index do |ts, idx|
      Rails.logger.debug "AHAO I am planning to run this task at: #{ts/1000}"
      Rails.logger.debug "AHAO Now it is #{Time.now.to_i}"
      Rails.logger.debug "AHAO The delta between us two is #{ts - Time.now.to_i }"
      # call call_rake to call script to take photos from here, passing in starting timestamp
      # and delta so that the camera can start doing work    
      Delayed::Job.enqueue(CameraSnapJob.new(@pset, idx), {:run_at => Time.at(ts/1000)});
    end

    render :json => @response
  end

  # Return the images available in the requested photoset.
  def photoset
    @photoset = PhotoSet.find params[:set_id].to_i
    
    # Hackish: hit the filesystem and return a list of files.    
    @response = {}
    @response[:images] = {}
    
    # Spin wait (ugh) until something shows up.
    while not File.directory?(@photoset.get_folder_path)
      sleep(1)
    end
    
    pset_dir = Dir.entries(@photoset.get_folder_path)
    pset_dir.reject! { |f| ['.', '..'].include?(f) }
    pset_dir.each_with_index do |f, idx|
        @response[:images][idx] = {:url => "#{@photoset.get_url_folder_path}/#{f}"}
    end

    render :json => @response
  end
end
