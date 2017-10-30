class OfflineController < ApplicationController
  include ActionController::Live
  # before_action :authenticate!

  def people
    if params[:since].blank?
      @people = Person.all
    else
      @people = Person.where(:updated_at.gte => params[:since])
    end
    # Hide the private stuff!
    stream_json_array(@people)
  end

  def update_visits
    current_user.last_visited = params[:ids]
    current_user.save!
  end

  private
  FLUSH_EVERY = 50

  def user2json(u)
    return PersonSerializer.new(u, as_seen_by: current_user).to_json
  end

  def stream_json_array(enum)
    response.headers["Content-Disposition"] = "attachment" # Download response to file. It's big.
    response.headers["Content-Type"]        = "application/json"
    response.headers["Content-Encoding"]    = "deflate"

    deflate = Zlib::Deflate.new

    buffer = "[ #{enum.count}"
    i = 0
    enum.each do |object|
      buffer << ",\n  "
      buffer << user2json(object)

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
