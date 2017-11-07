
Mongoid::Fields.option(:internal) do
  #nothing
end

class Person
  include Mongoid::Document
  include Mongoid::Timestamps
  include Elasticsearch::Model


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
  field :devices, type: Hash, internal: true
  field :salt, type: String, internal: true
  has_many :follows, :dependent => :destroy
  field :last_visited, type: Array, internal: true # Do this as array of IDs for simplicity

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

  def register_device(device)
    d = devices || {}
    d[device["uuid"]] = device
    self.devices = d
    save!
  end

  # Elasticsearch stuff

  # Define the index
  settings do
    mappings dynamic: 'false' do
      indexes :id, index: 'not_analyzed'
      indexes :roles, type: 'string'
      indexes :name, type: 'string'
      indexes :intro_bio, type: 'string'
      indexes :preferred_contact, index: 'not_analyzed', type: "keyword"
      indexes :affiliations, type: 'nested' do
        indexes :organisation
        indexes :position
        indexes :website
      end
      indexes :gender, index: 'not_analyzed'
      indexes :country, index: 'not_analyzed', type: "keyword"
      indexes :memberships, index: 'not_analyzed', type: "keyword"
      indexes :experience, index: 'not_analyzed', type: "keyword"
      indexes :regions, index: 'not_analyzed', type: "keyword"
    end
  end

  def self.aggs
    return {
      experience: { terms: { field: "experience" } },
      regions: { terms: { field: "regions" } },
      country: { terms: { field: "country" } }
    }
  end

  def self.elasticsearch_search(q)
    if q.class == String
      q = { query_string: { query: q }}
    end
    # Let's just make this a bit friendlier
    r = search(query: q, aggregations: Person.aggs)
    aggs = {}
    ["experience", "regions", "country"].each do |agg|
      aggs[agg] = r.aggregations[agg].buckets.map {|x| {x["key"] => x.doc_count}}.reduce Hash.new, :merge
    end
    return Hashie::Mash.new({
      response: r,
      total_records: r.results.total,
      aggregations: aggs
    })
  end

  def similar
    q = { more_like_this: {
      min_doc_freq: 1,
      min_term_freq: 1,
      fields: ["experience", "regions", "country", "memberships"],
      like: [ {
        _index: __elasticsearch__.index_name,
        _type: __elasticsearch__.document_type,
        _id: id.to_s
        }]
      } }
    return Person.elasticsearch_search(q)
  end
end
