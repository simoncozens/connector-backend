require 'RMagick'
require 'base64'
require 'csv'
require 'open-uri'

def save_picture(url)
  puts "Fetching "+url
  picture = open(url).read
  image = Magick::Image.from_blob(picture).first
  image = image.resize_to_fill(200,200)
  data_uri = "data:image/jpeg;base64,"+Base64.encode64(image.to_blob).gsub(/\n/, "")
  return data_uri
end

field_map = {:citizenship => "Country of Citizenship",
  :country => "Country of Residence",
  :languages_spoken => "Primary Language",
  :skype_id => "Skype ID",
  :twitter_id => "Twitter",
  :facebook_id => "Facebook",
  :linkedin_id => "LinkedIn",
  :intro_bio => "Introductory bio",
  :intro_video => "Self-Introduction Video (YouTube)",
}

CSV.foreach("LausanneConnector1LeaderInfo.csv", :headers => true) do |row|
  puts row["display_name"]
  p = Person.where(email: row["user_email"]).first_or_create
  # p.crypted_password=
  # p.name = row["display_name"] # Needs un-HTML-Escaping
  if row["avatar"]
    begin
      p.picture = save_picture(row["avatar"])
    rescue Exception => e
      puts e
    end
  end
  field_map.each do |m,c|
      if !row[c].blank? && (p.send(m)).blank?
        p.write_attribute(m,row[c])
      end
  end
  p.save
end
