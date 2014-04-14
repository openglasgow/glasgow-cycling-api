# == Schema Information
#
# Table name: routes
#
#  id                 :integer          not null, primary key
#  name               :string(255)
#  lat                :float
#  long               :float
#  total_distance     :float
#  mode               :integer
#  start_picture_id   :integer
#  end_picture_id     :integer
#  created_at         :datetime
#  updated_at         :datetime
#  start_time         :datetime
#  end_time           :datetime
#  total_time         :integer
#  user_id            :integer
#

class Route < ActiveRecord::Base
	has_one :review, :foreign_key => 'route_id', :class_name => "RouteReview"
	has_many :points, :foreign_key => 'route_id', :class_name => "RoutePoint"
	belongs_to :user

	before_validation :ensure_distance_exists
	before_validation :set_endpoints
	before_validation :calculate_times
	before_save :set_name
	before_save :set_maidenheads

	validates :name, presence: true
	validates :total_distance, presence: true
	validates :lat, presence: true
	validates :long, presence: true
	# validates :total_time, presence: true
	# validates :start_time, presence: true
	# validates :end_time, presence: true
	# TODO validate at least one point exists

	reverse_geocoded_by :lat, :long

	enum mode: [:bike, :walking]

	def to_coordinates
		[lat, long]
	end

	def similar
		return unless start_maidenhead.present? and end_maidenhead.present?
		a_to_z = Route.where(start_maidenhead: start_maidenhead, end_maidenhead: end_maidenhead)
		a_to_z
	end

	# Records a new route for the given user
	#
	# ==== Parameters
	# [+user+] the user who the route is being recorded against
	# [+points+] an array of points to be created as RoutePoints
	#
	# ==== Returns
	# The recorded route
	def self.record(user, points)
		if points.blank?
			return {
				error: "No route points"
			}
		end
		# Create the route
		route = Route.new
		route.name = "New Route" #TODO name properly
		route.user_id = user.id
		points.each do |point|
			route_point = RoutePoint.create do |rp|
				rp.lat = point[:lat]
				rp.long = point[:long]
				rp.altitude = point[:altitude]
				rp.kph = point[:speed] if point[:speed]
				rp.kph = point[:kph] if point[:kph]
				rp.time = Time.at(point[:time].to_i)
				rp.vertical_accuracy = point[:vertical_accuracy]
				rp.horizontal_accuracy = point[:horizontal_accuracy]
				rp.course = point[:course]
				rp.street_name = point[:street_name] if point[:street_name].present?
			end
			route.points << route_point
		end

		route.mode = "bike"

		route.save
		route
	end

	# Records a new review against the route and the provided user
	#
	# ==== Parameters
	# [+user+] user making the review
	# [+review_data+] data needed to create the review
	#
	# ==== Returns
	# The recorded review
	def create_review(user, review_data)
		return unless review_data[:safety_rating] and review_data[:difficulty_rating] and
		review_data[:environment_rating]
		review = RouteReview.create do |review_instance|
			review_instance.safety_rating = review_data[:safety_rating]
			review_instance.difficulty_rating = review_data[:difficulty_rating]
			review_instance.environment_rating = review_data[:environment_rating]
			review_instance.comment = review_data[:comment]
		end
		self.review = review
		user.reviews << review
		if user.save and self.save
			review
		else
			nil
		end
	end

	# Returns details for a route in format required by Route Controller
	#
	# ==== Returns
	# The route details.
	# TODO Picture URL returned
	# TODO update controller docs to match format & attrs
	def details
		user = User.where(id: self.user_id).first
		route_details = {
			id: self.id,
			total_distance: self.total_distance,
			created_by: {
				user_id: self.user_id,
				first_name: user.first_name,
				last_name: user.last_name
				},
			name: self.name,
			user_time: self.total_time,
			created_at: self.created_at.to_i
		}

		if self.review.present?
			route_details[:environment_rating] = self.review.environment_rating
			route_details[:safety_rating] = self.review.safety_rating
			route_details[:difficulty_rating] = self.review.difficulty_rating
		end

		last_point = self.points.last
		if last_point
			end_lat = last_point.lat
			end_long = last_point.long
			route_details[:end_picture]= Picture.for_location(end_lat, end_long)
		end
		route_details
	end

	# Returns points for a route in format required by Route Controller
	#
	# ==== Returns
	# The route points
	def points_data
		points = []
		route_points = RoutePoint.where(route_id: id)
		route_points.each do |point|
			points << {
				lat: point.lat,
				long: point.long,
				altitude: point.altitude,
				time: point.time
			}
		end
	end

	private

	def ensure_distance_exists
		return if self.total_distance.present? and self.total_distance > 0

		# Calculate route distance
		self.total_distance = self.points.each_with_index.inject(0) do |dist, (elem, index)|
			if index >= self.points.length - 1
				dist
			else
				next_point = self.points[index+1]
				dist += next_point.distance_from(elem)
			end
		end
	end

	def set_endpoints
		# Ensure endpoints get geocoded
		return if self.points.length == 0

		start = self.points.first
		start.is_important = true
		self.lat = start.lat
		self.long = start.long

		self.points.last.is_important = true
	end

	def calculate_times
		return if self.points.length == 0

		self.start_time = self.points.first.time
		self.end_time = self.points.last.time
		self.total_time = self.end_time - self.start_time
	end

	def set_name
		return if self.points.count == 0
		start_name = self.points.first.street_name
		end_name = self.points.last.street_name
		if start_name.present? and end_name.present?
			self.name = "#{start_name} to #{end_name}"
		elsif start_name.present?
			self.name = "From #{start_name}"
		elsif end_name.present?
			self.name = "To #{end_name}"
		else
			self.name = "Glasgow City Route"
		end
	end

	def set_maidenheads
		return if self.points.blank?
		self.start_maidenhead = self.points.first.maidenhead
		self.end_maidenhead = self.points.last.maidenhead
	end
end
