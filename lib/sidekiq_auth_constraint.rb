# Authorization constraint, used by the Sidekiq routes, that ensures that there
# exists a current user session.

class SidekiqAuthConstraint

  # Determines whether a user can access the Sidekiq admin page.
  #
  # @param [ActionDispatch::Request] request A request.
  # @return [true, false] Whether the user can access the Sidekiq admin page.

  def self.authorized?(request)
    return false unless request.session[:user_id]
    user = User.find(request.session[:user_id])
    !user.nil?
  end
end
