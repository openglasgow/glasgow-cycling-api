class UserController < ApplicationController
  doorkeeper_for :all, except: [:signup, :forgot_password]

  # *POST* /signup
  #
  # Registers a new user based on the given details.
  #
  # ==== Parameters
  # +user+ - JSON object containing user details to be registered. See example for all fields.
  # +user.email+:: must be an unregistered email address
  # +user.password+:: must be at least 8 characters long
  # +user.username+:: Required. String
  # +user.year_of_birth+:: Required. Year of birth
  # +user.gender+:: Required.rfemale, male or not disclosed
  # +user.profile_picture+:: Optional. Base64 encoding of JPG profile picture
  #
  # ==== Example +user+ object
  #  {
  #    email: 'user@email.com',
  #    password: 'user_password',
  #    username: 'john',
  #    year_of_birth: 1990,
  #    gender: 0,
  #    profile_picture: "base64 encoded JPG image data"
  #  }
  #ho
  # ==== Returns
  # Successful registration:
  #  {
  #    user_token: 'authentication_token'
  #  }
  def signup
  	unless params[:user]
  		render status: :bad_request, json: {}
  	else
  		user = User.register params[:user]
  		if user.valid?
        access_token = Doorkeeper::AccessToken.create!(:application_id => params[:client_id], :resource_owner_id => user.id)
        render json: {access_token: access_token.token}
  		else
        render :json => { :errors => user.errors.as_json }, :status => 422
  		end
  	end
  end

  # *GET* /details
  #
  # Returns the user overview details for the logged in user
  #
  # ==== Parameters
  # Takes a user email address and an authentication token.
  #
  # *Note:* The authentication token should always be used. This means that a user password
  # should not have to be stored by the client.
  #
  # [+user_email+] Email address of a user.
  # AND
  # [+user_token+] authentication token for a user
  #
  # ==== Returns
  # User details:
  #  {
  #    username: "chris",
  #    user_id: 1234,
  #    month{
  #        total: 12,
  #        km: 69,
  #        seconds: 6306
  #    },
  #    gender: undisclosed,
  #    email: chris@chris.com,
  #    profile-picture: base64img
  #  }
  def details
		Rails.logger.info "Getting user details"
    if user_signed_in?
      user = User.where(id: current_user.id).first
      render json: user.details
    else
      render status: :unauthorized, json: {error: "No user details"}
    end
  end

  # *PUT* /details
  #
  # Update the user account details
  #
  #  # ==== Parameters
  # Takes a updated user details and saves these against authenticated user
  #
  # [+user_email+] Email address of a user.
  # AND
  # [+user_details+] new user details
  #
  # ==== Returns
  def update_details
		Rails.logger.info "Updating user details"
		user = User.update(current_user.id, user_details_params)
    if user and user.save
			render json: user.details
		else
			render status: :internal_server_error, json: {errors: user.errors.as_json}
		end
  end

  # *POST* /responses
  #
  def save_responses
    unless params[:responses] and user_signed_in?
      render status: :bad_request, json: {}
    else
      response = UserResponse.store(params[:responses], current_user.id)
      if response
        render json: {}
      else
        render status: :internal_server_error, json: {error: "Unable to save responses"}
      end
    end
  end

  # *POST* /forgot_password
  def forgot_password
    user = User.where('LOWER(email) = ?', params[:email].downcase).first
    if user.present?
      user.send_reset_password_instructions
      render json: {email: user.email}
    else
      render status: :bad_request, json: {error: "No user with given email"}
    end
  end

  def reset_password
    if current_user.valid_password? params[:old_password]
      user = current_user
      user.password = params[:new_password]
      if user.save
        access_token = Doorkeeper::AccessToken.create!(:application_id => params[:client_id], :resource_owner_id => user.id)
        render json: {access_token: access_token.token}
      else
        render status: :bad_request, json: {error: "New password is invalid"}
      end
    else
      render status: :unauthorized, json: {error: "Invalid password"}
    end
  end

  private

  def failure
    Rails.logger.info "Login failed"
  end

	def user_details_params
		params.permit(:username, :profile_pic, :gender, :email)
	end
end
