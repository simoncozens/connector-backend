module SalesforceSerialization
  extend ActiveSupport::Concern

  @@sf_serialize_affiliations = {
    to_salesforce: -> affiliations, updates {
      org1 = affiliations[0]
      if org1
        # Org name is a link, just to be tricksy
        updates["Organization_Website__c"] = org1["website"]
        updates["Title"] = org1["position"]
      end
      if affiliations[1]
        org2 = affiliations[1]
        updates["Org_2_Temp__c"]= org2["organisation"]
        updates["Org_2_Title__c"] = org2["position"]
        updates["Org_2_Website__c"] = org2["website"]
      end
    },
    from_salesforce: -> sf_person, mongo_person {
      mongo_person.affiliations = [
        {organisation: sf_person["Temp_Organization__c"], website: sf_person["Organization_Website__c"], position: sf_person["Title"]}
      ]
      if sf_person["Org_2_Temp__c"]
        mongo_person.affiliations.push({organisation: sf_person["Org_2_Temp__c"], website: sf_person["Org_2_Website__c"], position: sf_person["Org_2_Title__c"]})
      end
    }
  }

  @@sf_serialize_phone = {
    to_salesforce: -> phone, updates {
      update["Phone"] = phone
    }, from_salesforce: -> sf_person, mongo_person {
      if !sf_person["Phone"].blank?
        mongo_person.phone = sf_person["Phone"]
      elsif sf_person["Primary_Cell_Check__c"]
        mongo_person.phone = sf_person["Contact_Preferred_Phone__c"]
      elsif sf_person["Secondary_Phone_Cell_Check__c"]
        mongo_person.phone = sf_person["Contact_Secondary_Phone__c"]
      end
    }
  }

  @@sf_serialize_catalyst = {
    to_salesforce: -> x,y { },
    from_salesforce: -> sf_person, mongo_person {
      if !sf_person["Lausanne_Leadership__c"].blank? and sf_person["Lausanne_Leadership__c"].include?("Catalyst") and !sf_person["Lausanne_Leadership_Title__c"].blank? and m = sf_person["Lausanne_Leadership_Title__c"].match(/Catalyst for (.*)/)
          mongo_person.catalyst = m[1]
          mongo_person.experience = [m[1]]
        end
    }
  }


  @@sf_serialize_events = {
    to_salesforce: -> x,y { },
    from_salesforce: -> sf_person, mongo_person {
      events = (sf_person["Event_Participation__c"]||[]).split(/;/)
      other_events = sf_person.attrs.select{|k,v| k.match(/^X/) && v}.keys.map{|x| x.gsub(/__c/,"").gsub(/_/, " ").gsub(/^X/,"") }
      mongo_person.events = events.append(other_events).flatten.uniq
      created = Date.parse(sf_person["CreatedDate"]).year.to_s
      event_years = mongo_person.events.map{|x| (m=x.match(/(\d\d\d\d)/)) && m[1] }
      event_years.unshift(created)
      mongo_person.joined_lausanne = event_years.sort.first
    }
  }

  # @@sf_serialize_interests = {
  #   ["Arts__c", "Buddhism__c", "Business_as_Mission__c", "Care_and_Counsel__c", "Children_at_Risk__c", "Church_Planting__c", "Church_Research__c", "Cities__c", "Creation_Care__c", "Diasporas__c", "Disability_Concerns__c", "Evangelism_among_Children__c", "Evangelism_Training__c", "Freedom_and_Justice__c", "Hinduism__c", "Integral_Mission__c", "Integrity_and_Anti_Corruption__c", "International_Student_Ministry__c", "Islam__c", "Jewish_Evangelism__c", "Leadership_Development__c", "Least_Evangelized_Peoples__c", "Marketplace_Ministry__c", "Media_Engagement__c", "Orality__c", "Partnership_of_Men_and_Women__c", "Proclamation_Evangelism__c", "Reconciliation__c", "Religious_Liberty__c", "Resource_Mobilization__c", "Scripture_Engagement__c", "Strategic_Evangelistic_Partnerships__c", "Study_of_Global_Christianity__c", "Technology__c", "Tentmaking__c", "Women_in_Evangelism__c"]
  # }

  @@sf_serialize_regions = {
    to_salesforce: -> x,y { },
    from_salesforce: -> sf_person, mongo_person {
      mongo_person.regions = [sf_person["Region__c"]]
    }
  }

  def sf_person
    if salesforce_id
      return SalesforceClient.find("Contact", salesforce_id)
    end
  end

  def to_salesforce
    return if not changed?
    return if not salesforce_id # For whatever reason?

    sf_updates = { "Id": salesforce_id }

    changed.each do |change|
      # For each field that's changed, we see if there is a
      # :salesforce option on that field definition (in person.rb)
      sf_opt = Person.fields[change].options[:salesforce]

      new_value = send(change) # This calls e.g. person.skype_id

      # If there's a one-to-one mapping to a SF field, job done.
      if sf_opt.is_a?(String)
        sf_updates[sf_opt] = new_value
      # Otherwise some code will be needed to get the value into
      # one or more SF fields. Call that code.
      elsif sf_opt.is_a?(Hash)
        sf_opt[:to_salesforce].call(new_value, sf_updates)
      end
    end

    UpdateSalesforceJob.perform_later(sf_updates)
  end

  def from_salesforce(sf_user)
    # For all of the fields which have some kind of marshalling defined:
    Person.fields.select {|k,f| f.options[:salesforce]}.each do |k,v|
      sf_opt = v.options[:salesforce]
      # If it's just a plain field, look up that field name in the hash
      # and store it in the object
      if sf_opt.is_a?(String)
        write_attribute(k, sf_user[sf_opt])
      # Otherwise find marshalling code and call it.
      elsif sf_opt.is_a?(Hash)
        sf_opt[:from_salesforce].call(sf_user, self)
      end
    end
  end

  def sync_from_salesforce
    from_salesforce(sf_person)
    # Normally when we save, we marshal back to SF. This is silly
    # if we've just received data *from* SF, so turn off that trigger.
    Person.skip_callback(:save, :before, :to_salesforce)
    save
    Person.set_callback(:save, :before, :to_salesforce)
  end

  included do
    before_save :to_salesforce
  end

  class_methods do
    def new_from_salesforce(id)
      p = Person.new
      p.salesforce_id = id
      p.password = p.password_confirmation = SecureRandom.uuid # XXX?
      p.sync_from_salesforce
      return p
    end

    def update_from_salesforce(sfid)
      c = Person.where(salesforce_id: sfid)
      if c.count == 0
        return new_from_salesforce(sfid)
      end
      p = c.first
      p.sync_from_salesforce
    end

    def salesforce_watcher
      SalesforceClient.watch do |m|
        Rails.logger.info("Salesforce object #{m["Id"]} updated, syncing")
        Person.update_from_salesforce(m["Id"])
      end
    end
  end
end