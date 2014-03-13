# == Schema Information
#
# Table name: pictures
#
#  id           :integer          not null, primary key
#  url          :string(255)
#  label        :string(255)
#  lat          :float
#  long         :float
#  credit_label :string(255)
#  credit_url   :string(255)
#  created_at   :datetime
#  updated_at   :datetime
#

class Picture < ActiveRecord::Base
	reverse_geocoded_by :lat, :long

	def self.for_location(route_lat, route_long)
		pic = Picture.near([route_lat, route_long], 50).first
		if pic
			{
				url: pic.url,
				label: pic.label,
				credit_label: pic.credit_label,
				credit_url: pic.credit_url
			}
		else
			pic = Picture.order("RANDOM()").limit(1).first
			return nil unless pic

			{
				url: pic.url,
				label: pic.label,
				credit_label: pic.credit_label,
				credit_url: pic.credit_url
			}
		end
	end

	def add(pic_data)
		#TODO Paperclip to allow adding

		#not for in app use, this is admin bit
	end
end
