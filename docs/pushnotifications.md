Push Notifications
==================

Push notifications are handled by the rpush gem, so you'll first want to read the docs for that. This is configured in `config/intializers/rpush.rb`, although I don't think we need to change any of the defaults.

How it actually works is done in as a mixin on the Person class (like everything else). See `app/concerns/push_notifications.rb`.

First, we have to get the information about a user's device. This information is in a hash which is sent to the `people/add_device` endpoint of the API, which means it appears in `PeopleController#add_device`. We store everything we get about the device in a hash on the current user's Mongo object. It's a hash keyed against the device's UUID, so that a) we don't get multiple entries for each device, and b) a user can get notifications on all the devices they register.

When we actually want to send a notification to a user, 