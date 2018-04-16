namespace :salesforce do
    desc "Salesforce change subscriber"
    task :subscriber => :environment do
      Person.salesforce_watcher
    end

    task :import_wheaton => :environment do
      Person.delete_all
      SalesforceClient.query("select Id from Contact where email like '%lausanne.org'").map{|x| Person.new_from_salesforce(x.Id)}
      SalesforceClient.query("select Id from Contact where Lausanne_Leadership__c='Catalyst'").map{|x| Person.new_from_salesforce(x.Id)}
      Person.where(name: "Friend").delete
      me = Person.where(name: "Simon Cozens").first
      me.password = "foobar"
      me.password_confirmation = "foobar"
      me.save!
    end
end