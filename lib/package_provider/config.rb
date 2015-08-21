require 'settingslogic'

module PackageProvider
  # class representing project configuration
  class Config < Settingslogic
    def initialize(source = nil, section = nil)
      source ||=
        File.join(PackageProvider.root, 'config', 'package_provider.yml')

      self.class.namespace PackageProvider.env
      super(source, section)
    end
  end
end
