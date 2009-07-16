module Sinatra
  # HTTP Authorization helpers for Sinatra.
  #
  # In your helpers module, include Sinatra::Authorization and then define
  # an #authorize(user, password) method to handle user provided
  # credentials.
  #
  # Inside your events, call #login_required to trigger the HTTP
  # Authorization window to pop up in the browser.
  #
  # Code adapted from {Ryan Tomayko}[http://tomayko.com/about] and
  # {Christopher Schneid}[http://gittr.com], shared under an MIT License
  module Authorization
    # Redefine this method on your helpers block to actually contain
    # your authorization logic.
    def authorize(username, password)
      false
    end

    # Call in any event that requires authentication
    def user_login
      return if logged_in?
      if auth.provided?
        bad_request!  unless auth.basic?
        unauthorized! unless authorize(*auth.credentials)
        request.env['REMOTE_USER'] = auth.username
      end
    end

    # Convenience method to determine if a user is logged in
    def logged_in?
      !!request.env['REMOTE_USER']
    end

    # Name provided by the current user to log in
    def current_user
      request.env['REMOTE_USER']
    end

    def unauthorized!(realm=Realm)
      response["WWW-Authenticate"] = %(Basic realm="#{realm}")
      throw :halt, [ 401, 'You are not authorized to do this' ]
    end

    private
      def auth
        @auth ||= Rack::Auth::Basic::Request.new(request.env)
      end

      def bad_request!
        throw :halt, [ 400, 'Bad Request' ]
      end
  end
end
