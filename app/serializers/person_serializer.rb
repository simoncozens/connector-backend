class PersonSerializer < ActiveModel::Serializer
  def attributes(requested_attrs = nil, reload = false)
    if not instance_options[:as_seen_by]
      raise "PersonSerializer instantiated without viewing user; use 'as_seen_by => current_user'"
    end
    @attributes ||= self.object.fields.select{|k,v| object.field_viewable?(v,instance_options[:as_seen_by]) }.each_with_object({}) do |(key, attr), hash|
        if key == "_id"
          hash["id"] = object.id.to_s
        else
          hash[key] = object.send(key)
        end
      end
  end
end