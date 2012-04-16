require 'dm-core'
require 'dm-migrations'
require 'dm-timestamps'

require 'nkf'

module Watchdog
  REPOSITORY_NAME = :watchdog

  def self.connect(path)
    path.parent.mkpath
    DataMapper.setup(REPOSITORY_NAME, "sqlite3://#{path}")
    Watchdog::Page.auto_upgrade!
  end

  ######################################################################
  ### Page

  class Page
    def self.default_repository_name; REPOSITORY_NAME; end
    def self.default_storage_name   ; "page"; end

    include DataMapper::Resource

    property :id        , Serial
    property :name      , String                     # 件名
    property :url       , String                     # 詳細
    property :digest    , String                     # DIGEST値
    property :changed   , Boolean , :default=>false  # 更新済
    property :changed_at, DateTime                   # changed_at

    ######################################################################
    ### Class methods

    class << self
      def changed
        all(:changed=>true, :order=>[:id])
      end

      def unchanged
        all(:changed=>false, :order=>[:id])
      end
    end

    ######################################################################
    ### Operations

    include Ircbot::Utils::HtmlParser

    def update!
      html = Open3.popen3("curl", url) {|i,o,e| o.read{} }
      utf8 = NKF.nkf("-w", html)
      hex  = Digest::SHA1.hexdigest(utf8)
      self[:changed]    = !! ( self[:changed] || (digest && (digest != hex)) )
      self[:name]       = get_title(utf8)
      self[:digest]     = hex
      self[:changed_at] = Time.now
      save
      return self[:changed]
    end

    ######################################################################
    ### Instance methods

    def done!
      self[:changed] = false
      save
    end

    def to_s
      "#{name} #{url}"
    end
  end
end