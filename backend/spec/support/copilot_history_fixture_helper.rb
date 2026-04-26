require "fileutils"
require "tmpdir"

module CopilotHistoryFixtureHelper
  def copilot_history_fixture_root(name)
    Rails.root.join("spec/fixtures/copilot_history", name)
  end

  def with_copilot_history_fixture(name)
    fixture_root = copilot_history_fixture_root(name)
    temp_root = Pathname.new(Dir.mktmpdir("copilot-history-fixture"))

    FileUtils.cp_r("#{fixture_root}/.", temp_root)

    yield temp_root
  ensure
    FileUtils.rm_rf(temp_root) if temp_root&.exist?
  end

  def with_permission_denied(path)
    target = path.is_a?(Pathname) ? path : Pathname.new(path.to_s)
    original_mode = target.stat.mode & 0o777

    File.chmod(0o000, target)
    yield target
  ensure
    File.chmod(original_mode, target) if original_mode && target&.exist?
  end
end
