
Mongoid::Fields.option(:internal) do
  #nothing
end

class Person
  include Mongoid::Document
  include Mongoid::Timestamps


  paginates_per 10
  authenticates_with_sorcery!

  # Profile fields
  field :roles, type: Array
  field :name, type: String
  field :intro_bio, type: String
  field :preferred_contact, type: String
  field :affiliations, type: Array
  field :experience, type: Array
  field :regions, type: Array
  field :gender
  field :picture
  field :country
  field :memberships, type: Array
  field :field_permissions, type: Hash, internal: true
  field :crypted_password, type: String, internal: true
  field :salt, type: String, internal: true
  has_many :follows, :dependent => :destroy
  field :last_visited, type: Array, internal: true # Do this as array of IDs for simplicity

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
