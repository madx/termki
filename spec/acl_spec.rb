describe TermKi::ACL do
  acl_file = File.join(File.dirname(__FILE__), 'users.yml')
  TermKi::ACL.load YAML.load_file(acl_file)

  describe '.login(user, password)' do
    it 'returns true if the user is authorized' do
      TermKi::ACL.login('admin', 'god').should.be.true
    end

    it 'returns false if there is no such user' do
      TermKi::ACL.login('void', 'foo').should.be.false
    end

    it 'returns false if the password is wrong' do
      TermKi::ACL.login('foo', 'foo').should.be.true
      TermKi::ACL.login('foo', 'bar').should.be.false
    end
  end

  describe '.user(name)' do
    it 'returns an user' do
      user = TermKi::ACL.user('admin')
      user.should.be.kind_of TermKi::User
      user.password.should =~ /\A[a-fA-F0-9]{64}\Z/
      user.groups.should.be.kind_of Array
    end
  end

  describe '.authorize(user, page, right)' do

    before do
      @p = {
        :g => {
          :o => TermKi::Page.new('og').tap { |p|
            p.mode = :open
            p.groups << 'group'
          },
          :r => TermKi::Page.new('rg').tap{ |p|
            p.mode = :restricted
            p.groups << 'group'
          },
          :p => TermKi::Page.new('pg').tap { |p|
            p.mode = :private
            p.groups << 'group'
          }
        },
        :ng=> {
          :o => TermKi::Page.new('on').tap { |p|
            p.mode = :open
          },
          :r => TermKi::Page.new('rn').tap{ |p|
            p.mode = :restricted
          },
          :p => TermKi::Page.new('pn').tap { |p|
            p.mode = :private
          }
        }
      }
      @admin = TermKi::ACL.user('admin')
      @foo   = TermKi::ACL.user('foo')
      @user  = TermKi::ACL.user('user')
    end

    it 'checks permissions for a non-logged user on a closed wiki' do
      TermKi.set :open, false
      results = []
      [:o, :r, :p].each do |m|
        [:g, :ng].each do |g|
          results << []
          [:r, :w].each do |r|
            results.last << TermKi::ACL.authorize(nil, @p[g][m], r)
          end
        end
      end
      results.should == [
        [true, false],  [true, false],
        [false, false], [false, false],
        [false, false], [false, false]
      ]
    end

    it 'checks permissions for a logged user or when the wiki is open' do
      TermKi.set :open, true
      logged    = []
      anonymous = []
      [:o, :r, :p].each do |m|
        [:g, :ng].each do |g|
          [logged, anonymous].each {|a| a << [] }
          [:r, :w].each do |r|
            logged.last    << TermKi::ACL.authorize(nil,  @p[g][m], r)
            anonymous.last << TermKi::ACL.authorize(@foo, @p[g][m], r)
          end
        end
      end
      logged.should == [
        [true,  true],  [true, true],
        [true,  false], [true, true],
        [false, false], [true, true]
      ]
      anonymous.should == logged
    end

    it 'checks permissions for users in the page groups and admins' do
      TermKi.set :open, false
      group, admin = [], []
      [:o, :r, :p].each do |m|
        [:g, :ng].each do |g|
          [group, admin].each {|a| a << [] }
          [:r, :w].each do |r|
            group.last << TermKi::ACL.authorize(@user,  @p[g][m], r)
            admin.last << TermKi::ACL.authorize(@admin, @p[g][m], r)
          end
        end
      end
      group.flatten.all? {|res| res.true? }.should.be.true
      admin.flatten.all? {|res| res.true? }.should.be.true
    end
  end
end
