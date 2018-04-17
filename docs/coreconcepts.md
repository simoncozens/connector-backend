Core Concepts
=============

## API routes

## Authentication

## Rails quickstart

## Web deployment

## Scripts and helpers

When a record changes, we update Salesforce (see separate docs for how this works) but we don't want to block the whole web server while this is happening, so we run it as a separate thread. This happens through the `UpdateSalesforceJob` defined in `app/jobs/update_salesforce_job.rb`, using the ActiveJob infrastructure. The `sidekiq` gem provides the ActiveJob plugin that makes this work. This is configured in `config/application.rb`:

    config.active_job.queue_adapter = :sidekiq

The Salesforce watcher, which subscribes to record updates from SF and manipulates our database appropriately, is started by calling `rake salesforce:subscriber`. See `lib/tasks/salesforce.rake` for where this is defined, and the Salesforce docs for how it works.