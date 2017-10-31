class PersonSerializer < ActiveModel::Serializer
  def attributes(requested_attrs = nil, reload = false)
    if object.class != Person
      return super
    end
    if not instance_options[:as_seen_by]
      raise "PersonSerializer instantiated without viewing user; use 'as_seen_by => current_user'"
    end
    viewer = instance_options[:as_seen_by]
    @attributes ||= self.object.fields.select{|k,v| object.field_viewable?(v,viewer) }.each_with_object({}) do |(key, attr), hash|
        if key == "_id"
          hash["id"] = object.id.to_s
        else
          hash[key] = object.send(key)
        end
      end
    @attributes["followed"] = viewer.following?(object)
    @attributes["annotation"] = Annotation.where(about: object,created_by: viewer).first
    return @attributes
  end
end