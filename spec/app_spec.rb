require 'rubygems'
require 'rack/test'

Bacon::Context.send :include, Rack::Test::Methods

App   = TermKi::App.new
page  = TermKi::Page.new('about')
page << TermKi::Revision.new('This is the about page')
App.wiki.add page

def app; App end

describe TermKi::App do

  describe 'initialization' do
    it 'creates a default wiki if none is given' do
      app.wiki.index.should.not.be.empty
    end
  end

  describe 'get /' do
    it 'returns the home page' do
      get '/'
      last_response.should.be.ok
      last_response.body.should.include App.wiki['home'].latest.contents
    end
  end

  describe 'get /_index_' do
    it 'returns the wiki index' do
      get '/_index_'
      last_response.should.be.ok
      App.wiki.index.each do |name, page|
        last_response.body.should.include page.latest.checksum
        last_response.body.should.include name
      end
    end
  end

  describe 'get /:name' do
    it 'returns the given page' do
      get '/home'
      last_response.should.be.ok
      last_response.body.should.include App.wiki['home'].latest.contents

      get '/about'
      last_response.should.be.ok
      last_response.body.should.include App.wiki['about'].latest.contents
    end

    it 'returns an error if there is no such page' do
      get '/void'
      last_response.status.should == 404
    end
  end

  describe 'get /:name/history' do
    it 'returns the history for a page' do
      get '/home/history'
      last_response.should.be.ok
      last_response.body.should.include App.wiki['home'].latest.checksum
      last_response.body.should.not.include App.wiki['home'].latest.contents
    end

    it 'returns an error if there is no such page' do
      get '/void/history'
      last_response.status.should == 404
    end
  end

  describe 'get /:name/:rev' do
    it 'returns the page at the given revision' do
      get "/home/#{App.wiki['home'].latest.checksum}"
      last_response.should.be.ok
      last_response.body.should.include App.wiki['home'].latest.contents
    end

    it 'returns an error if there is no such revision' do
      get '/home/bad'
      last_response.status.should == 404
    end

    it 'returns an error if there is no such page' do
      get '/void'
      last_response.status.should == 404
    end
  end

  describe 'post /:name' do
    it 'creates a new page with the given contents an returns it' do
      post '/new', :body => "This is a new page"
      last_response.should.be.ok
      App.wiki['new'].should.not.be.nil
      App.wiki.destroy('new')
    end

    it 'returns an error if the contents are missing' do
      post '/new'
      last_response.status.should == 500
      last_response.body.should.include 'missing body'
      App.wiki['new'].should.be.nil
    end

    it 'returns an error if the page already exists' do
      post '/home'
      last_response.status.should == 403
      last_response.body.should.include 'already exists'
    end

    it 'returns an error if the name is a reserved one' do
      post '/__index__'
      last_response.status.should == 403
      last_response.body.should.include 'reserved'
    end
  end

  describe 'put /:name' do
    it 'updates a page with the given contents an returns it' do
      put '/about', :body => "New contents"
      last_response.should.be.ok
      last_response.body.should.include "New contents"
      App.wiki['about'].latest.contents.should.include "New contents"
    end

    it 'returns an error if the contents are missing' do
      latest = App.wiki['about'].latest
      put '/about'
      last_response.status.should == 500
      last_response.body.should.include 'missing body'
      App.wiki['about'].latest.should == latest
    end

    it 'returns an error if there is no such page' do
      put '/void'
      last_response.status.should == 404
    end
  end

  describe 'delete /:name' do
    it 'deletes a page' do
      delete '/about'
      last_response.should.be.ok
      App.wiki['about'].should.be.nil
    end

    it 'returns an error if there is no such page' do
      delete '/void'
      last_response.status.should == 404
    end
  end

end
