require 'sinatra/base'
require 'digest/sha2'
require 'zlib'
require File.join(File.dirname(__FILE__), 'sinatra', 'authorization')

Sinatra::Authorization.const_set :Realm, 'TermKi'

class TermKi < Sinatra::Base

  class Wiki
    attr_reader :index

    def self.load(fileish)
      Marshal.load(Zlib::Inflate.inflate(fileish.read))
    end

    def initialize
      @index = {}
    end

    def [](name)
      @index[name]
    end

    def add(page)
      fail "\"#{page.name}\" is already in the index" if @index[page.name]
      @index[page.name] = page
    end

    def destroy(name)
      @index.delete(name) { |el| fail "no such page \"#{el}\"" }
    end

    def dump(fileish)
      fileish << Zlib::Deflate.deflate(Marshal.dump(self))
    end
  end


  class Page
    attr_reader   :name, :revisions
    attr_accessor :mode, :groups

    def initialize(name)
      @name = name
      @mode = :open
      @groups = []
      @revisions = {}
    end

    def push(rev)
      rev.bind self
      @revisions[rev.checksum] ||= rev
    end
    alias << push

    def latest
      @revisions.values.max { |a,b| a.timestamp <=> b.timestamp }
    end

    def history
      @revisions.values.sort { |a,b|
        a.timestamp <=> b.timestamp
      }.reverse
    end

    def revision(checksum)
      matches = @revisions.keys.select do |rev|
        rev =~ Regexp.new("^#{checksum}")
      end

      case matches.size
        when 0: nil
        when 1: @revisions[matches.first]
        else    fail "ambiguous revision #{checksum}"
      end
    end
    alias [] revision
  end


  class Revision
    attr_reader :contents, :timestamp, :checksum

    def initialize(contents)
      @contents  = contents
      @checksum  = nil
      @timestamp = Time.now
    end

    def bind(page)
      fail "already bound to #{page.name}" if @checksum
      @checksum = Digest::SHA2.hexdigest([
        rand,
        page.name,
        @timestamp.to_i
      ].join('+'))
    end
  end


  class User
    attr_reader :password, :groups

    def initialize(password, groups)
      @password, @groups = password, groups || []
    end

    def in_groups?(groups)
      groups.any? {|g| @groups.include?(g) }
    end

    def admin?
      groups.include?('wheel')
    end
  end


  module ACL
    class << self
      def load(acl_hash)
        @users = {}
        acl_hash.each do |user, params|
          @users[user] = User.new(params[:password], params[:groups])
        end
      end

      def login(user, password)
        return false unless @users.key?(user)
        @users[user].password == Digest::SHA2.hexdigest(password)
      end

      def user(name)
        @users[name]
      end

      def authorize(user, page, right)
        if user || TermKi.open
          user ||= User.new(nil, nil)
          return true if user.in_groups?(page.groups)  ||
                         user.admin?                   ||
                         page.groups.empty?            ||
                         page.mode == :open            ||
                         page.mode == :restricted && right == :r
          false
        else
          [page.mode, right] == [:open, :r]
        end
      end
    end
  end


  # App
  @@wiki = nil
  def wiki() @@wiki end

  def self.setup!
    if File.file?(store)
      @@wiki = File.open(store, 'r') { |f| Wiki.load(f) }
    else
      @@wiki = Wiki.new
      home = Page.new('home')
      rev = Revision.new('This is the default TermKi home page')
      home << rev
      @@wiki.add(home)
    end
  end

  configure do
    set :store, 'wiki.db'
    set :open,  false
    set :realm, "TermKi"
  end

  helpers do
    include Sinatra::Authorization

    def authorize(username, password)
      ACL.login(username, password)
    end

    def render(page, rev)
      String.new.tap { |out|
        out << "Resource: /#{page.name}/#{rev.checksum}\n"
        out << "Modified: #{rev.timestamp.xmlschema}\n"
        out << "---\n"
        out << "#{rev.contents}"
      }
    end

    def valid_page!
      unless @page = wiki[params[:page]]
        throw :halt, [404, "Page '%s' not found" % params[:page] ]
      end
    end

    def valid_rev!
      unless @rev = @page[params[:rev]]
        throw :halt, [404, "Revision %s not found for page '%s'" %
                           [ params[:rev], params[:page] ] ]
      end
    end

    def admin_only!
      unless current_user && ACL.user(current_user).admin?
        unauthorized!
      end
    end

    def filter!(page, mode)
      ACL.authorize(ACL.user(current_user), page, mode) || unauthorized!
    end
  end

  before do
    content_type 'text/plain'
    user_login
  end

  get '/__commit__' do
    admin_only!
    begin
      File.open(options.store, 'w+') { |s| wiki.dump(s) }
      "Changes have been commited"
    rescue => e
      "Error during commit: #{e.message}"
    end
  end

  get '/__index__' do
    (buffer = "").tap do |buf|
      wiki.index.each do |name, page|
        latest = page.latest
        count  = page.revisions.size
        buf << "Resource: /#{name}/#{latest.checksum}"
        buf << " (#{count} revision#{count == 1 ? '' : 's'})\n"
        buf << "Modified: #{latest.timestamp.xmlschema}\n"
        buf << "---\n"
      end
    end

    buffer
  end

  get '/' do
    redirect '/home'
  end

  get '/:page' do
    valid_page!
    filter!(@page, :r)

    render @page, @page.latest
  end

  get '/:page/:rev' do
    valid_page!
    filter! @page, :r

    valid_rev!

    render @page, @rev
  end

  post '/:page' do
    page = Page.new(params[:page])
    if params[:mode] && %w[open restricted private].include?(params[:mode])
      page.mode = params[:mode].to_sym
    end
    page << (rev = Revision.new(params[:contents]))

    begin
      wiki.add page
    rescue RuntimeError => e
      throw :halt, [500, e.message]
    end

    render page, rev
  end

  put '/:page' do
    valid_page!
    filter! @page, :w

    @page << (rev = Revision.new(params[:contents]))

    render @page, rev
  end

  delete '/:page' do
    valid_page!
    filter! @page, :w

    if params[:page] == 'home'
      throw :halt, [500, "You can't destroy the home page"]
    end
    wiki.destroy params[:page]

    "Page '#{params[:page]}' has been destroyed"
  end

  delete '/:page/:rev' do
    valid_page!
    filter! @page, :w

    valid_rev!

    if params[:page] == 'home' && @page.revisions.size == 1
      throw :halt, [500, "You can't destroy the home page"]
    end

    @page.revisions.delete(@rev.checksum)

    out = "Revision #{params[:rev]} has been destroyed"
    if @page.revisions.empty?
      wiki.destroy @page.name
      out << "\nPage '#{@page.name}' has been destroyed"
    end
    out + "\n"
  end

end
