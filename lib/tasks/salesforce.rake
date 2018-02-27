namespace :salesforce do
    desc "Salesforce change subscriber"
    task :subscriber => :environment do
      Person.salesforce_watcher
    end
end