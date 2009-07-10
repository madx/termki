describe TermKi::Revision do

  describe 'initialization' do
    before do
      @rev = TermKi::Revision.new('Contents')
    end
    it 'initializes with contents' do
      @rev.contents.should == 'Contents'
      @rev.should.be.kind_of TermKi::Revision
    end

    it 'sets the timestamp' do
      @rev.timestamp.should.be.kind_of Time
    end

    it 'has contents, timestamp and checksum read-only attributes' do
      [:contents, :timestamp, :checksum].each do |meth|
        @rev.should.respond_to     meth
        @rev.should.not.respond_to "#{meth}="
      end
    end
  end

  describe '#bind(page)' do
    before do
      @rev  = TermKi::Revision.new('Contents')
      @page = Struct.new(:name).new('page')
    end

    it 'sets the checksum' do
      @rev.bind @page
      @rev.checksum.should =~ /\A[a-f0-9]{40}\Z/
    end

    it 'adds random to the checksum to avoid collisions' do
      rev1 = TermKi::Revision.new('Contents')
      rev2 = TermKi::Revision.new('Contents')
      rev1.bind @page
      rev2.bind @page
      rev1.checksum.should.not == rev2.checksum
    end

    it 'raises an error if the checksum is already set' do
      @rev.bind @page
      lambda {
        @rev.bind @page
      }.should.raise RuntimeError, "already bound to #{@page.name}"
    end
  end

end
