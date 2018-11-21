require "lakebed"

RSpec::describe "rtld" do
  describe "RoModule::Relocate" do
    before do
      @emu = Lakebed::Emulator.new
      @emu.add_nso(rtld)
    end

    def emu
      @emu
    end
    
    def nso
      @nso||= @emu.add_nso(@builder.build)
    end
    
    def module_object
      nso.get_symbol("_module_object")
    end
    
    def reach_relocate
      expect(emu).to write_to(module_object + 0x10, [0].pack("L<")) # jmprel is written last... for some reason
    end

    it "processes R_AARCH64_RELATIVE relocations in RELA section" do
      @builder = Lakebed::NsoBuilder.new(:rel => :rela)

      test_section = @builder.add_section([0].pack("Q<"), :data)
      test_section.add_dynamic_relocation(0, Lakebed::Elf::R_AARCH64_RELATIVE, nil, 0x140)
      
      reach_relocate
      expect(emu).to read_from(module_object + 0x98, 8) # read rel_count
      expect(emu).to write_to(nso + test_section.to_location.to_i, [nso + 0x140].pack("Q<"))
      expect(emu).to read_from(module_object + 0x98, 8) # reread rela_count
    end

    it "processes R_AARCH64_RELATIVE relocations in REL section" do
      @builder = Lakebed::NsoBuilder.new(:rel => :rel)

      test_section = @builder.add_section([0].pack("Q<"), :data)
      test_section.add_dynamic_relocation(0, Lakebed::Elf::R_AARCH64_RELATIVE, nil, 0x140)
      
      reach_relocate

      expect(nso.read(test_section.to_location.to_i, 8)).to eq([0x140].pack("Q<"))
      
      expect(emu).to read_from(module_object + 0x90, 8) # read rel_count
      expect(emu).to read_from(module_object + 0x18, 8) # read rela
      expect(emu).to read_from(nso + test_section.to_location.to_i, 8) # read original value
      expect(emu).to write_to(nso + test_section.to_location.to_i, [nso + 0x140].pack("Q<")) # add aslr offset
      expect(emu).to read_from(module_object + 0x90, 8) # reread rel_count
    end

    it "skips non-R_AARCH64_RELATIVE relocations in RELA section" do
      @builder = Lakebed::NsoBuilder.new(:rel => :rela)

      test_section = @builder.add_section([0].pack("Q<"), :data)
      test_section.add_dynamic_relocation(0, Lakebed::Elf::R_AARCH64_GLOB_DAT, nil, 0x140)

      expect do
        reach_relocate
        expect(emu).to read_from(module_object + 0x90, 8) # read rel_count
        expect(emu).to read_from(module_object + 0x98, 8) # read rela_count
        expect(emu).to read_from(module_object + 0x18, 8) # read rela
        expect(emu).to read_from(module_object + 0x0, 8) # read prev
      end.not_to write_to(emu, nso + test_section.to_location.to_i, 8)
    end

    it "skips non-R_AARCH64_RELATIVE relocations in REL section" do
      @builder = Lakebed::NsoBuilder.new(:rel => :rel)

      test_section = @builder.add_section([0].pack("Q<"), :data)
      test_section.add_dynamic_relocation(0, Lakebed::Elf::R_AARCH64_GLOB_DAT, nil, 0x140)

      expect do
        reach_relocate
        expect(emu).to read_from(module_object + 0x90, 8) # read rel_count
        expect(emu).to read_from(module_object + 0x18, 8) # read rela
        expect(emu).to read_from(module_object + 0x0, 8) # read prev
      end.not_to write_to(emu, nso + test_section.to_location.to_i, 8)
    end
  end
end
