namespace :salesforce do
    desc "Salesforce change subscriber"
    task :subscriber => :environment do
      Person.salesforce_watcher
    end

    task :import_wheaton => :environment do
      Person.delete_all
      SalesforceClient.query("select Id from Contact where email like '%lausanne.org'").map{|x| Person.new_from_salesforce(x.Id)}
      SalesforceClient.query("select Id from Contact where Lausanne_Leadership__c != null").map{|x| Person.new_from_salesforce(x.Id)}
      Person.where(name: "Friend").delete
    end
end