# frozen_string_literal: true

module CookieSameSiteCompat
  extend ActiveSupport::Concern

  def cookie_same_site_none(useragent)
    cookie_same_site_none_incompatible?(useragent) ? :nil : :none
  end

  def cookie_same_site_none_incompatible?(useragent)
    webkit_same_site_bug?(useragent) || drops_unrecognized_same_site_cookies?(useragent)
  end

  private

  IOS_VERSION_REGEXP = %r{\(iP.+; CPU .*OS (\d+)[_\d]*.*\) AppleWebKit/}
  MACOS_VERSION_REGEXP = %r{\(Macintosh;.*Mac OS X (\d+)_(\d+)[_\d]*.*\) AppleWebKit/}
  SAFARI_REGEXP = %r{Version/.* Safari/}
  CHROMIUM_BASED_REGEXP = /Chrom(?:e|ium)/
  CHROMIUM_VERSION_REGEXP = %r{Chrom[^ /]+/(\d+)[.\d]* }
  MAC_EMBEDDED_REGEXP = %r{^Mozilla/[.\d]+ \(Macintosh;.*Mac OS X [_\d]+\) AppleWebKit/[.\d]+ \(KHTML, like Gecko\)$}
  UC_BROWSER_REGEXP = %r{UCBrowser/}
  UC_BROWSER_VERSION_REGEXP = %r{UCBrowser/(\d+)\.(\d+)\.(\d+)[.\d]* }

  def webkit_same_site_bug?(useragent)
    return true if ios_version?(12, useragent)

    if macos_version?(10, 14, useragent)
      return true if SAFARI_REGEXP.match?(useragent) && !CHROMIUM_BASED_REGEXP.match(useragent)
      return true if MAC_EMBEDDED_REGEXP.match?(useragent)
    end

    false
  end

  def ios_version?(major, useragent)
    IOS_VERSION_REGEXP.match(useragent) do |ios_version|
      return true if ios_version[1].to_i == major
    end

    false
  end

  def macos_version?(major, minor, useragent)
    MACOS_VERSION_REGEXP.match(useragent) do |macos_version|
      return true if macos_version[1].to_i == major && macos_version[2].to_i == minor
    end

    false
  end

  def drops_unrecognized_same_site_cookies?(useragent)
    return !uc_browser_version_at_least?(12, 13, 2, useragent) if uc_browser?(useragent)
    return chromium_version_in?(51...67, useragent) if chromium_based?(useragent)

    false
  end

  def chromium_based?(useragent)
    CHROMIUM_BASED_REGEXP.match?(useragent)
  end

  def chromium_version_in?(range, useragent)
    CHROMIUM_VERSION_REGEXP.match(useragent) do |chromium_version|
      return range.include?(chromium_version[1].to_i)
    end

    false
  end

  def uc_browser?(useragent)
    UC_BROWSER_REGEXP.match?(useragent)
  end

  def uc_browser_version_at_least?(major, minor, build, useragent)
    UC_BROWSER_VERSION_REGEXP.match(useragent) do |uc_version|
      major_version = uc_version[1].to_i
      minor_version = uc_version[2].to_i
      build_version = uc_version[3].to_i
      return major_version > major if major_version != major
      return minor_version > minor if minor_Version != minor

      return build_version >= build
    end

    false
  end
end
