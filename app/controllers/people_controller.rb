class PeopleController < ApplicationController
  before_action :set_person, only: [:show, :edit, :destroy, :follow, :unfollow, :annotate, :add_to_network]
  before_action :authenticate!
  before_action :authenticate_as_admin!, only: [ :new ]
  # GET /people
  # GET /people.json
  def index
    page = params[:page] || 1
    @people = Person.search_from_params(params).page(page)
    render_people
  end

  def recommended
    page = params[:page] || 1
    @people = current_user.similar(params).response.page(page).records
    render_people
  end

  # GET /people/1
  # GET /people/1.json
  def show
    current_user.visit(@person)
    followed = current_user.following?(@person)
    p = PersonSerializer.new(@person, as_seen_by: current_user).as_json
    render :json => p
  end

  def annotate
    ann = Annotation.first_or_create(about: @person,created_by: current_user)
    ann.content = params[:content]
    ann.save!
    render :json => { :ok => 1 }
  end

  # Following

  def follow
    current_user.follow!(@person)
    render :json => { :ok => 1 }
  end

  def unfollow
    current_user.unfollow!(@person)
    render :json => { :ok => 1 }
  end

  def following
    if params["fts"]
      # mongoid does not directly support where clauses on has_many
      # relationships, so we have to fake it
      followed_ids = current_user.follows.map(&:followed_user_id)
      @people =  Person.where(:$text => { :$search => params["fts"] }, :id.in => followed_ids)
      @people = @people.page(params[:page]||1)
      render_people
    else
      @people = current_user.follows.page(params[:page]||1)
      render_people &:followed_user
    end
  end

  def recent
    @people = Kaminari.paginate_array(Person.find(current_user.last_visited)).page(params[:page]||1)
    render_people
  end

  def update
    to_update = person_params_user
    if to_update[:picture]
      to_update[:picture] = square_crop(to_update[:picture])
    end

    target = current_user
    if current_user.is_admin? and params[:id]
      # You, and only you, can update somebody else.
      target = Person.find(params[:id])
    end

    if target.update(to_update)
      render :json => { :ok => 1 }
    else
      render json: target.errors, status: :unprocessable_entity
    end
  end

  def new
    @person = Person.new(params.require(:user).permit!)
    if @person.save
      return show
    end
    render json: { :ok => 0, :errors => @person.errors }, status: :unprocessable_entity
  end

  def add_device
    device = params[:device]
    if device and device.key?("uuid")
      current_user.register_device(device)
      render :json => { :ok => 1 }
    else
      render :nothing => true, :status => 400
    end
  end

  # Catalysts can add to network
  def add_to_network
    if !current_user.catalyst
      render :nothing => true, :status => 400
    else
      @person.experience ||= []
      @person.experience |= [current_user.catalyst] # Add without dupe
      @person.save
      render :json => { :ok => 1 }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_person
      @person = Person.find(params[:id])
    end

    # What can a user edit about themselves?
    def person_params_user
      params.fetch(:person, {}).permit(
        :intro_bio, :short_bio,
        :skype_id, :linkedin_id, :twitter_id, :facebook_id,
        :picture,
        :country, :city,
        :phone, :languages_spoken, :primary_language,
        :birthdate, 
        :affiliations => [[:organisation, :position, :website]],
        :experience => [],
        :regions => [],
        :field_permissions => [ :preferred_contact => [] ]
      )
    end

    def render_people # Like they do in Fight Club
      render :json => {
        :current_page => @people.current_page,
        :total_entries => @people.total_count,
        :entries => block_given? ?
         @people.map{|p| PersonSerializer.new(yield(p), as_seen_by: current_user).as_json }
         : @people.map{|p| PersonSerializer.new(p, as_seen_by: current_user).as_json }
      }
    end

    def square_crop(picture)
      image = Magick::Image.read_inline(picture).first
      image = image.resize_to_fill(200,200)
      return "data:image/jpeg;base64,"+Base64.encode64(image.to_blob).gsub(/\n/, "")
    end
end
