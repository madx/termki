require 'rubygems'
require 'rack/test'
require File.join(File.dirname(__FILE__), 'fakefs')

class File
  alias_method :<<, :write
end

TermKi.set :environment, :test

Bacon::Context.send :include, Rack::Test::Methods

describe TermKi do

  it 'has extended options' do
    TermKi.should.respond_to :store
  end

  describe '.setup!' do
    TermKi.set :store, lambda { File.join(File.dirname(__FILE__), 'void.db') }

    before do
      TermKi.class_eval('@@wiki = nil')
      def get_wiki
        TermKi.class_eval('@@wiki')
      end
    end

    after do
      TermKi.class_eval('@@wiki = nil')
    end

    it 'setups a basic wiki when there is no store' do
      TermKi.setup!
      wiki = get_wiki
      wiki.should.be.kind_of TermKi::Wiki
      wiki.index.size.should == 1
      wiki['home'].revisions.size.should == 1
    end

    it 'should load from the store' do
      wiki = TermKi::Wiki.new
      page = TermKi::Page.new('home')
      page << TermKi::Revision.new('Starting text')
      page << TermKi::Revision.new('Updated text')

      wiki.add page

      File.open(TermKi.store, 'w+') { |s| wiki.dump(s) }

      TermKi.setup!
      wiki = get_wiki
      wiki.should.be.kind_of TermKi::Wiki
      wiki.index.size.should == 1
      wiki['home'].revisions.size.should == 2
    end
  end

  describe 'Routes' do
    TermKi.set :store, lambda { File.join(File.dirname(__FILE__), 'mock.db') }
    wiki = TermKi::Wiki.new
    %w[home about].each {|n| wiki.add TermKi::Page.new(n) }
    wiki['home'] << TermKi::Revision.new('This is the home page')
    wiki['about'] << TermKi::Revision.new('This is the about page')
    File.open(TermKi.store, 'w+') { |s| wiki.dump(s) }

    before do
      def app() TermKi end
      TermKi.setup!
      @wiki = TermKi.class_eval('@@wiki')
    end

    describe 'content_type' do
      it 'is set to text/plain for each request' do
        get '/'
        last_response.headers['Content-Type'].should == 'text/plain'
      end
    end

    describe 'get /__index__' do
      it 'returns the wiki index' do
        get '/__index__'
        last_response.should.be.ok
        last_response.body.tap do |body|
          body.should =~ %r{#{@wiki['home'].latest.checksum}}
          body.should =~ %r{#{@wiki['about'].latest.checksum}}
        end
      end
    end

    describe 'get /' do
      it 'redirects to /home' do
        get '/'

        last_response.headers['Location'].should == '/home'
        follow_redirect!

        last_request.url.should =~ %r{/home$}
      end
    end

    describe 'get /:name' do
      it 'renders the page named :name if it exits' do
        get '/home'
        last_response.body.should.include @wiki['home'].latest.contents
      end

      it 'raises an error if the page does not exist' do
        get '/void'
        last_response.status.should == 404
      end
    end

    describe 'get /:name/:rev' do
      it 'renders a given revision for a page' do
        get '/home'
        body = last_response.body

        get "/home/#{@wiki['home'].latest.checksum}"
        last_response.body.should == body
      end

      it 'raises an error if the page does not exist' do
        get '/void/void'
        last_response.status.should == 404
      end

      it 'raises an error if the revision does not exist' do
        get '/home/void'
        last_response.status.should == 404
      end
    end

    describe 'post /:name' do
      it 'creates a new page' do
        @wiki['new'].should.be.nil

        post '/new', :contents => "Hello, world"
        last_response.should.be.ok
        last_response.body.should.include "Hello, world"

        @wiki['new'].should.not.be.nil
      end

      it 'raises an error if the page already exists' do
        post '/home', :contents => "Contents"
        last_response.should.not.be.ok
        last_response.body.should == '"home" is already in the index'
      end
    end

    describe 'put /:name' do
      it 'creates a new revision for a page' do
        put '/home', :contents => "a new version"
        last_response.should.be.ok
        last_response.body.should.include "a new version"
        @wiki['home'].revisions.size.should == 2
      end

      it 'raises an error if the page does not exist' do
        put '/void', :contents => "Contents"
        last_response.status.should == 404
      end
    end

    describe 'delete /:name' do
      it 'destroys a page' do
        delete '/about'
        last_response.should.be.ok
        @wiki['about'].should.be.nil
      end

      it 'fails on the home page' do
        delete '/home'
        last_response.should.not.be.ok
        @wiki['home'].should.not.be.nil
      end

      it 'raises an error if the page does not exist' do
        delete '/void'
        last_response.status.should == 404
      end
    end

    describe 'delete /:name/:rev' do
      it 'destroys a given revision of a page' do
        @wiki['about'] << (rev = TermKi::Revision.new('contents'))
        @wiki['about'].revisions.size.should == 2
        delete "/about/#{rev.checksum}"
        @wiki['about'].revisions.size.should == 1
      end

      it 'destroys the page if there are no more revisions' do
        delete "/about/#{@wiki['about'].latest.checksum}"
        @wiki['about'].should.be.nil
      end

      it 'should not destroy if this is the last revision for the home page' do
        delete "/home/#{@wiki['home'].latest.checksum}"
        last_response.should.not.be.ok
        last_response.body.should.include "destroy the home page"
      end

      it 'raises an error if the page does not exist' do
        delete '/void/void'
        last_response.status.should == 404
      end

      it 'raises an error if the revision does not exist' do
        delete '/about/void'
        last_response.status.should == 404
      end
    end
  end
end
