# Note: The libraries I'm using here aren't available in the dev version but are included in the release version.
# However it's not recommended to use these libraries for other purposes because JoiPlay doesn't fully support them.
# See the JoiPlay directory for details.

class Updater
  @@available_version = nil
  @@download_message_window = nil
  @@download_progress = nil
  @@log = ""

  def self.shouldUseBuiltInUpdater?
    return GAMEVERSION != 'dev'
  end

  def self.log(message)
    @@log += message + "\n"
  end

  def self.logError(error)
    self.log error.full_message
    puts @@log
    File.open(RTP.getSaveFolder + "/updater.log", "ab") { |f| f.write(@@log) }
  end

  def self.initializeAvailableVersion
    self.log 'GAMETITLE = ' + GAMETITLE.inspect
    self.log 'GAMEVERSION = ' + GAMEVERSION.inspect
    self.log 'VERSION_URL = ' + VERSION_URL.inspect
    self.log 'PATCH_URL = ' + PATCH_URL.inspect
    self.log 'TILESETS_URL = ' + TILESETS_URL.inspect if $joiplay
    self.log 'PATCH_USER = ' + PATCH_USER.inspect
    shouldUse = self.shouldUseBuiltInUpdater?
    self.log 'shouldUseBuiltInUpdater? ' + shouldUse.inspect
    return unless shouldUse

    self.log 'Initializing available version'
    begin
      gem 'rubygems'

      if $joiplay
        # On JoiPlay we don't have net/http available so we have to use HTTPLite.
        response = HTTPLite.get(VERSION_URL)
        if response[:status] == 200
          version_string = response[:body].strip
          if Gem::Version.correct?(version_string)
            @@available_version = version_string
            self.log 'Detected remote version ' + version_string
            return
          end
          self.log 'Invalid remote version string ' + version_string
        else
          self.log 'Unable to get latest game version (http code ' + response[:status].to_s + ')'
        end
        # Can't get latest version.
        return
      end

      gem 'net/http'
      uri = URI(VERSION_URL)
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.open_timeout = 5
        http.read_timeout = 5
        http.request(Net::HTTP::Get.new(uri)) do |response|
          if response.code == '200'
            version_string = response.body.strip
            if Gem::Version.correct?(version_string)
              @@available_version = version_string
              self.log 'Detected remote version ' + version_string
              return
            end
            self.log 'Invalid remote version string ' + version_string
          else
            self.log 'Unable to get latest game version (http code ' + response.code + ')'
          end
          # Can't get latest version.
          return
        end
      end
    rescue MKXPError => error
      self.log 'Unknown error when getting latest version'
      self.logError error
      return
    rescue => error
      self.log 'Unknown error when getting latest version'
      self.logError error
      return
    end
  end

  def self.getAvailableVersion
    return @@available_version
  end

  # Returns a number indicating the status of the current version vs the remote version
  # 0 - One of the versions is invalid so we can't compare them
  # 1 - Local version is somehow newer than remote version, normally this should not happen
  # 2 - Local version is up to date
  # 3 - New patch update is available
  # 4 - New major update is available
  def self.getVersionStatus
    status = self.getVersionStatusInternal
    self.log 'Detected version status ' + status.inspect
    self.log 'One of the versions is invalid so we can\'t compare them' if status == 0
    self.log 'Local version is somehow newer than remote version, normally this should not happen' if status == 1
    self.log 'Local version is up to date' if status == 2
    self.log 'New patch update is available' if status == 3
    self.log 'New major update is available' if status == 4
    return status
  end

  def self.getVersionStatusInternal
    return 0 if @@available_version.nil?
    return 0 unless Gem::Version.correct?(@@available_version)
    return 0 unless Gem::Version.correct?(GAMEVERSION)

    version = Gem::Version.new(GAMEVERSION)
    latest = Gem::Version.new(@@available_version)
    return 1 if version > latest
    return 2 if version == latest
    return 3 if getBaseVersion(GAMEVERSION) == getBaseVersion(@@available_version)

    return 4
  end

  def self.getBaseVersion(version)
    return Gem::Version.new(version.gsub(/([0-9]+)$/, '0'))
  end

  def self.downloadPatch(authorization)
    self.log 'Attempting update...'
    begin; File.delete('patch.zip'); rescue; end

    msgwindow = Kernel.pbCreateMessageWindow
    @@download_message_window = msgwindow
    @@download_progress = 0
    Kernel.pbMessageDisplay(msgwindow, _INTL("Downloading patch... {1}%\\wtnp[0]", "0"))
    msgwindow.textspeed = -999

    begin
      url = PATCH_URL

      if $joiplay
        # Headers don't seem to work with HTTPLite.download so I had to use a php redirect as a band-aid.
        if authorization != ''
          url += '.php?auth=' + authorization
        end

        self.log 'Patch url ' + url.inspect
        response = HTTPLite.download(url, 'patch.zip', 'patchDownloadProgress')
        self.log 'Patch http code ' + response[:status].inspect
        if response[:status] == 401
          self.log 'Incorrect password'
          return false
        end
        if response[:status] != 200
          self.log 'Unexpected http code'
          raise 'Unexpected response code ' + response[:status].to_s
        end

        self.log 'Patch successfully downloaded'
        return true
      end

      gem 'net/http'

      self.log 'Patch url ' + url.inspect
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(uri)
        if authorization != ''
          request['Authorization'] = 'Basic ' + authorization
          self.log 'authorization = Basic ' + authorization
        end

        http.request(request) do |response|
          self.log 'Patch http code ' + response.code.inspect
          if response.code == '401'
            self.log 'Incorrect password'
            return false
          end
          if response.code != '200'
            self.log 'Unexpected http code'
            raise 'Unexpected response code ' + response.code
          end

          self.log 'Downloading patch...'
          total = response['content-length'].to_i
          progress = 0
          File.open('patch.zip', 'wb') do |file|
            response.read_body do |chunk|
              file.write(chunk)
              progress += chunk.length
              downloadProgress(progress, total, "Downloading patch...")
            end
          end
          if progress != total
            self.log 'Downloaded ' + progress + ' but the expected total is ' + total
            raise 'Downloaded ' + progress + ' but the expected total is ' + total
          end
          self.log 'Patch successfully downloaded'
        end
      end
      return true
    rescue MKXPError => error
      self.log 'Patch download failed'
      self.logError error

      Kernel.pbMessageDisplay(msgwindow, _INTL("The download has failed."))
      raise error
    rescue => error
      self.log 'Patch download failed'
      self.logError error

      Kernel.pbMessageDisplay(msgwindow, _INTL("The download has failed."))
      raise error
    ensure
      Kernel.pbDisposeMessageWindow(msgwindow)
    end
  end

  def self.downloadProgress(progress, total, message)
    percent = progress * 100 / total
    if @@download_progress <= percent - 10
      # The key was built by concatenating the caller's message in, so it could
      # never match an entry in the table. Both halves are looked up separately.
      Kernel.pbMessageDisplay(@@download_message_window,
                              _INTL("\\se[]{1} {2}%\\wtnp[0]", _INTL(message), percent.to_s),
                              tts: percent == 100)
      @@download_progress += 10
    end
  end

  def self.downloadTilesets(authorization)
    begin; File.delete('tilesets.zip'); rescue; end

    msgwindow = Kernel.pbCreateMessageWindow
    @@download_message_window = msgwindow
    @@download_progress = 0
    Kernel.pbMessageDisplay(msgwindow, _INTL("Downloading optimized tilesets... {1}%\\wtnp[0]", "0"))
    msgwindow.textspeed = -999

    begin
      url = TILESETS_URL

      # Headers don't seem to work with HTTPLite.download so I had to use a php redirect as a band-aid.
      if authorization != ''
        url += '.php?auth=' + authorization
      end

      self.log 'Tilesets url ' + url.inspect
      response = HTTPLite.download(url, 'tilesets.zip', 'tilesetsDownloadProgress')
      self.log 'Tilesets http code ' + response[:status].inspect
      if response[:status] == 401
        self.log 'Incorrect password'
        return false
      end
      if response[:status] != 200
        self.log 'Unexpected http code'
        raise 'Unexpected response code ' + response[:status].to_s
      end

      self.log 'Tilesets successfully downloaded'
      return true
    rescue => error
      self.log 'Tilesets download failed'
      self.logError error

      Kernel.pbMessageDisplay(msgwindow, _INTL("The download has failed."))
      raise error
    ensure
      Kernel.pbDisposeMessageWindow(msgwindow)
    end
  end

  def self.applyPatch(patch, directory)
    self.log 'Applying patch ' + patch
    self.log 'Directory ' + directory
    begin
      gem 'zip'
      gem 'fileutils'
      # Can't report progress because Zip::File.count_entries is only in rubyzip 3.0 which isn't released.
      Zip::File.open(patch) do |zip_file|
        zip_file.each do |file|
          path = directory + '/' + file.name
          FileUtils.mkdir_p(File.dirname(path))
          zip_file.extract(file, path) { true }
        end
      end
    rescue => error
      self.log 'Unable to apply patch'
      self.logError error

      Kernel.pbMessage(_INTL("Unable to apply the patch."))
      raise error
    ensure
      begin; File.delete(patch); rescue; end
    end
  end

  def self.handleAuthorization
    authorization = ''
    if PATCH_USER != ''
      self.log 'Asking for password'

      gem 'base64'

      password = pbEnterText(_INTL("Password?"), 0, 20)
      authorization = Base64.encode64(PATCH_USER + ':' + password).strip
      self.log 'Trying to authorize using password ' + password.inspect
    else
      self.log 'No authorization needed'
    end

    return authorization
  end

  def self.handlePatchUpdate
    if Kernel.pbConfirmMessage(_INTL("Do you want to download the latest patch?"))
      authorization = self.handleAuthorization

      # Optimized tilesets are only used on JoiPlay.
      if self.downloadPatch(authorization) && (!$joiplay || self.downloadTilesets(authorization))
        if $joiplay
          Kernel.pbMessage(_INTL("Applying tilesets...\\wtnp[10]"))
          self.applyPatch('tilesets.zip', '.')
        end

        Kernel.pbMessage(_INTL("Applying patch...\\wtnp[10]"))
        self.applyPatch('patch.zip', '.')

        if $joiplay
          begin; File.delete('.path_cache'); rescue; end
          begin; File.delete('.file_list'); rescue; end
        end

        Kernel.pbMessage(_INTL("Your game has been updated!\nExiting to apply the changes."))
        exit
      else
        Kernel.pbMessage(_INTL("Incorrect password."))
      end
    end
  end

  def self.handleMajorUpdate
    Kernel.pbMessage(_INTL("You're currently playing version {1}.", GAMEVERSION))
    Kernel.pbMessage(_INTL("Version {1} is a major release and needs to be installed manually.", self.getAvailableVersion))
  end

  def self.waitForVersionCheck
    return if GAMEVERSION == 'dev'
    # Sleep until available version is detected, up to 2 seconds.
    # Mainly needed for people who start the game in debug mode and thus skip the game intro scene.
    200.times do
      break if self.getAvailableVersion != nil
      sleep(0.01)
    end
  end
end

def patchDownloadProgress(progress, total)
  Updater.downloadProgress(progress, total, "Downloading patch...")
end

def tilesetsDownloadProgress(progress, total)
  Updater.downloadProgress(progress, total, "Downloading optimized tilesets...")
end

# Check updater in separate thread so that website issues don't delay game start.
if $joiplay
  # Calling HTTPLite.get in a thread while not connected to internet causes an unrecoverable JoiPlay crash.
  Updater.initializeAvailableVersion
else
  Thread.new do
    Updater.initializeAvailableVersion
  end
end
