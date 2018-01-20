
Mongoid::Fields.option(:internal) do
  #nothing
end

Mongoid::Fields.option(:salesforce) do
  #nothing
end

class Person
  include Mongoid::Document
  include Mongoid::Timestamps
  include SalesforceSerialization
  include PushNotifications
  include ElasticsearchSearchability

  paginates_per 10
  authenticates_with_sorcery!
  validates :password, length: { minimum: 3 }, if: -> { new_record? || changes[:crypted_password] }
  validates :password, confirmation: true, if: -> { new_record? || changes[:crypted_password] }
  validates :password_confirmation, presence: true, if: -> { new_record? || changes[:crypted_password] }

  # Profile fields
  field :roles, type: Array
  field :email, type: String, salesforce: "Email"
  field :name, type: String, salesforce: "Name"
  field :intro_bio, type: String
  field :preferred_contact, type: String
  field :affiliations, type: Array, salesforce: @@sf_serialize_affiliations
  field :experience, type: Array
  field :regions, type: Array
  field :gender, salesforce: "Gender__c"
  field :picture
  field :intro_video
  field :country, salesforce: "Country_of_Residence__c"
  field :citizenship, salesforce: "Country_of_Citizenship__c"
  field :memberships, type: Array
  field :field_permissions, type: Hash, internal: true
  field :crypted_password, type: String, internal: true
  field :devices, type: Hash, internal: true
  field :salt, type: String, internal: true
  has_many :follows, :dependent => :destroy
  field :last_visited, type: Array, internal: true # Do this as array of IDs for simplicity
  field :salesforce_id, internal: true


  def as_indexed_json(options={})
    as_json(only: Person.searchable_fields.keys-["_id"])
  end

  def field_viewable?(field,other)
    return false if field.options[:internal]
    return true if other.roles.include?("admin")
    # More here
    return false if field_permissions.key?(field) and not field_permissions[field]
    return true
  end

  def self.searchable_fields
    fields.select{|k,v| !v.options[:internal]}
  end

  def follow!(user)
    follows.create(followed_user_id: user.id)
  end

  def unfollow!(user)
    follows.where(followed_user_id: user.id).destroy
  end

  def following?(user)
    follows.where(followed_user_id: user.id).exists?
  end

  def visit(user)
    l = self.last_visited || []
    l.unshift(user.id).uniq!
    l.slice!(6)
    self.last_visited = l
    save!
  end

  def self.search_from_params(params)
    clause = params.slice(*searchable_fields)
    if params["fts"] and !params["fts"].empty?
      clause[:$text] = { :$search => params["fts"] }
    end
    self.where(clause)
  end

end
