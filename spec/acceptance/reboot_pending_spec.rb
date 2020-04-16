require 'spec_helper_acceptance'

describe 'Windows Provider - Pending Reboot' do
  if os[:family] == 'windows'
    let(:reboot_manifest) do
      <<-MANIFEST
        reboot { 'now':
          when => pending
        }
      MANIFEST
    end
    let(:pending_reboot_manifest) do
      <<-MANIFEST
        registry_key { 'HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired':
          ensure => present,
        }
      MANIFEST
    end

    # Undo the Registry Changes for Required Reboot
    after(:all) do
      undo_pending_reboot_manifest = <<-MANIFEST
        registry_key { 'HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\WindowsUpdate\\Auto Update\\RebootRequired':
          ensure => absent,
        }
        MANIFEST
      apply_manifest(undo_pending_reboot_manifest, catch_failures: true)
    end

    it 'Declare Reboot Required in the Registry' do
      apply_manifest(pending_reboot_manifest, catch_failures: true)
      expect(reboot_issued_or_cancelled).to be(true)
    end

    it 'Reboot if Pending Reboot Required' do
      apply_manifest(reboot_manifest, catch_failures: true)
      expect(reboot_issued_or_cancelled).to be(true)
    end

    original_name = run_shell('cmd /c hostname').stdout.chomp
    new_name = ('a'..'z').to_a.sample(12).join

    it "Rename the computer to #{new_name} temporarily" do
      run_shell(PuppetLitmus::Util.interpolate_powershell("\"& { (Get-WmiObject -Class Win32_ComputerSystem).Rename('#{new_name}') }\""))
    end

    it 'Reboot if Pending Reboot Required' do
      apply_manifest(reboot_manifest, catch_failures: true)
      expect(reboot_issued_or_cancelled).to be (true)
    end

    if original_name
      it "Rename the computer back to #{original_name}" do
        run_shell(PuppetLitmus::Util.interpolate_powershell("\"& { (Get-WmiObject win32_computersystem).Rename('#{original_name}') }\""))
      end
    end
  end
end
