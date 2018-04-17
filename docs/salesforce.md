Salesforce Integration
======================

This is some of the hairiest part of the code.

## Client

We use the `restforce` client library to communicate with Salesforce. This relies on having some environment variables set, which for obvious reasons are not stored in the repository. We have to pass the hostname manually, however. I don't know why.

The client is represented in Ruby as a singleton, `SalesforceClient`. (Defined in `app/services/salesforce_client.rb` - Rails autoloads everything in this directory.) Any method you call on this singleton is proxied to the `restforce` object.

## Serialization - pushing to salesforce

The serialization is handled by a concern which lives in `app/models/concerns/salesforce_serialization.rb`. This concern is explicitly mixed in to the `Person` model. It also creates a trigged on the saving of a Person object:

  included do
    before_save :to_salesforce
  end

Comments in this function should help you understand how the data gets up to SF. The easy case is when we can just store the data in a corresponding SF field. The hard case is when we have to do some work to get it there; in those cases we call a marshalling function.

In some situations, one part of the Ruby/Mongo object maps to several different fields in SF - for instance, "organisations" is an array of hashes, each with title/org/website properties. So we give the marshalling function maximum flexibility by passing it the new value and the whole hash which is storing the changes we will send up to SF, and let it sort it out.

## Serialization - from salesforce

A similarly flexibility is needed when we are getting new data from SF. This will happen in two cases: when we instantiate a new user into Connector from their SF profile, and when we receive notification from SF that an update has happened outside of Connector. Once again, if it's a plain field, the situation is easy. `email` in Mongo is `Email` in SF, as defined here:

  field :email, type: String, salesforce: "Email"

So when we get information from SF, we can call `sf_data["Email"]` to get the data and store it in `person.email`. When things require more processing, we actually send a function two objects: the hash containing the SF data (because you might need to access more than one field to pull together your data - once again, think organisations), and the Ruby/Mongo object so you can call whatever methods on it you need to feed it the data.

So the "tricky" marshalling functions are a hash of lambda functions:

    {
        to_salesforce: -> (field_value, sf_data) { ... },
        from_salesforce: -> (sf_person, mongo_person) { ... },
    }

Slightly asymmetrical, but seems to work best. Because these are hashes, they're stored as class variables (`@@foo`) which get imported into the `Person` class when the mixin is loaded; that's how they can be used in the field definitions.

## Syncing and Instantiating

`sf_person` is a method on a Ruby/Mongo `Person` object which looks up their salesforce ID (stored in Mongo) and then goes and asks the SF client for the record about that person. So, to sync a Ruby/Mongo person with canonical data from Salesforce, we call `sync_from_salesforce`. This gets the `sf_person`, marshals it through `from_salesforce` to set the Mongo attributes with the values from SF, and then saves it.

To instantiate a person given a SF ID, we call `new_from_salesforce`. This creates a new person with a dummy password and then syncs them as above. (Perhaps one day we might need a method which instantiates someone by email address. This should be fairly similar.) We also have `update_from_salesforce` which tries to find someone with a given SF ID in our database; if they're there, we sync them, and if they're not, we instantiate them.

## Subscribing to SF changes

This `update_from_salesforce` method comes in very useful when we have a notification from SF that a record has been created or updated. The `SalesforceClient` singleton has a method called `watch`, which creates (if necessary) and then subscribes to a topic, receiving an ID from SF when a record is created or updated. It then puts that ID into a hash and hands it off to the block you give it.

    SalesforceClient.watch { |o| puts("Hey, "+o["Id"]+" just changed!") }

Or indeed:

    SalesforceClient.watch { |o| Person.update_from_salesforce(o["Id"]) }

which is essentially what `Person.salesforce_watcher` does.