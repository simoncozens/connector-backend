class OfflineController < ApplicationController
  include ActionController::Live
  before_action :authenticate!

  def people
    if params[:since]
      @people = Person.where(:updated_at.gte => params[:since])
    else
      @people = Person.all
    end
    # Hide the private stuff!
    stream_json_array(@people)
  end

  private
  FLUSH_EVERY = 50

  def stream_json_array(enum)
    response.headers["Content-Disposition"] = "attachment" # Download response to file. It's big.
    response.headers["Content-Type"]        = "application/json"
    response.headers["Content-Encoding"]    = "deflate"

    deflate = Zlib::Deflate.new

    buffer = "[ #{enum.count}, \n  "
    i = 0
    enum.each do |object|
      buffer << ",\n  " unless i == 0
      buffer << PersonSerializer.new(object).to_json

      if i % FLUSH_EVERY == 0
        write(deflate, buffer)
        buffer = ""
      end
      i=i+1
    end
    buffer << "\n]\n"

    write(deflate, buffer)
    write(deflate, nil) # Flush deflate.
    response.stream.close
  end

  def write(deflate, data)
    deflated = deflate.deflate(data)
    response.stream.write(deflated)
  end
end
