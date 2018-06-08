module ElasticsearchSearchability
    extend ActiveSupport::Concern

    included do
      # Define the index
      include Elasticsearch::Model
      include Elasticsearch::Model::Callbacks
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
    end

    class_methods do
      def aggs
        return {
          experience: { terms: { field: "experience" } },
          regions: { terms: { field: "regions" } },
          country: { terms: { field: "country" } }
        }
      end

      def elasticsearch_search(q)
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
    end

    def similar(params)
      mlt = { more_like_this: {
        min_doc_freq: 0,
        min_term_freq: 0,
        fields: ["experience", "regions", "country", "memberships"],
        like: [ {
          _index: __elasticsearch__.index_name,
          _type: __elasticsearch__.document_type,
          _id: id.to_s
          }]
        } }
      q = { bool: { should: mlt , must: { match_all: {} } } }
      if params[:fts]
        q[:bool][:must] = { query_string: { query: params[:fts] } }
      end
      return Person.elasticsearch_search(q)
    end
end