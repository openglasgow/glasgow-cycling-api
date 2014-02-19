class UserController < ApplicationController
  def signup
  	unless params[:user]
  		render status: :bad_request
  	else
  		user = User.register JSON.parse(params[:user])
  		if user
  			render json: {auth_token: user.authentication_token}
  		else
  			render status: :internal_server_error
  		end
  	end
  end

  def signin
  	if user_signed_in?
  		render json: {auth_token: current_user.authentication_token}
  	else
  		render status: :unauthorized
  	end
  end
end
