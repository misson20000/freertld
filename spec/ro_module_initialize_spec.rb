require "lakebed"

RSpec::describe "rtld" do
  describe "RoModule::Initialize" do
    before do
      @emu = Lakebed::Emulator.new
      @emu.add_nso(rtld)

      @builder = Lakebed::NsoBuilder.new
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
    
    def reach_initialize
      expect(emu).to read_from(nso.get_symbol("_mod0") + 6 * 4, 4)
    end

    it "initializes prev and next to self-pointers" do
      reach_initialize
      # we can only hook one of STP's writes...
      expect(emu).to write_to(module_object + 8, [module_object].pack("Q<"))
    end

    it "initializes fields correctly" do
      reach_initialize
      expect(emu).to write_to(module_object + 0x20, [nso.base_addr].pack("Q<"))
      expect(emu).to write_to(module_object + 0x28, [nso.get_symbol("_dynamic_start")].pack("Q<"))
      # everything else is just NULL initialized, so doesn't matter much...
    end

    describe "dynamic fields" do
      # values
      {"DT_PLTRELSZ" => 0x38,
       "DT_RELASZ" => 0x80,
       "DT_STRSZ" => 0x70,
       "DT_RELSZ" => 0x88,
       "DT_RELACOUNT" => 0x98,
       "DT_RELCOUNT" => 0x90,
      }.each_pair do |tag, offset|
        it "stores the value for #{tag} at module object + 0x#{offset.to_s(16)}" do
          magic = "MY64BITS"
          @builder.add_dt(Lakebed::Elf.const_get(tag), magic.unpack("Q<").first)

          reach_initialize
          expect(emu).to read_from(nso.get_symbol("_dynamic_start"))
          expect(emu).to write_to(module_object + offset, magic)
        end
      end
      
      # addresses
      {
        "DT_JMPREL" => 0x10, # this is strangely deferred
        "DT_RELA" => 0x18,
        "DT_REL" => 0x18,
        "DT_INIT" => 0x40,
        "DT_FINI" => 0x48,
        "DT_STRTAB" => 0x60,
        "DT_SYMTAB" => 0x68,
        "DT_PLTGOT" => 0x78,
      }.each_pair do |tag, offset|
        it "stores the address for #{tag} at module_object + 0x#{offset.to_s(16)}" do
          @builder.add_dt(Lakebed::Elf.const_get(tag), 0xabcd)

          reach_initialize
          expect(emu).to read_from(nso.get_symbol("_dynamic_start"))
          expect(emu).to write_to(module_object + offset, [nso + 0xabcd].pack("Q<"))
        end
      end

      describe "DT_PLTREL" do
        it "stores 1 if the value == DT_RELA" do
          @builder.add_dt(Lakebed::Elf::DT_PLTREL, Lakebed::Elf::DT_RELA)

          reach_initialize
          expect(emu).to read_from(nso.get_symbol("_dynamic_start"))
          expect(emu).to write_to(module_object + 0x30, [1].pack("C"))
        end
        it "stores 0 if the value != DT_RELA" do
          @builder.add_dt(Lakebed::Elf::DT_PLTREL, Lakebed::Elf::DT_REL)

          reach_initialize
          expect(emu).to read_from(nso.get_symbol("_dynamic_start"))
          expect(emu).to write_to(module_object + 0x30, [0].pack("C"))
        end
        it "breaks if the value is neither DT_REL nor DT_RELA" do
          @builder.add_dt(Lakebed::Elf::DT_PLTREL, 0xabcd)

          reach_initialize
          expect(emu).to read_from(nso.get_symbol("_dynamic_start"))
          expect(emu).to call_svc(0x26).and_return(0)
        end
      end

      # assertions
      {"DT_RELENT" => 16,
       "DT_SYMENT" => 24,
       "DT_RELAENT" => 24}.each_pair do |tag, expected|
        it "breaks if #{tag} != #{expected}" do
          @builder.add_dt(Lakebed::Elf.const_get(tag), 0xabcd)
          
          reach_initialize
          expect(emu).to read_from(nso.get_symbol("_dynamic_start"))
          expect(emu).to call_svc(0x26).and_return(0)
        end
      end

      describe "DT_HASH" do
        before do
          @hash_section = @builder.add_section([0x1234, 0xabcd, 0x5678].pack("L<*"), :data)
          @builder.add_dt(Lakebed::Elf::DT_HASH, @hash_section.to_location)
          
          reach_initialize
          expect(emu).to read_from(nso.get_symbol("_dynamic_start"))
        end

        it "stores hash_nchain at +0xa0" do
          expect(emu).to write_to(module_object + 0xa0, [0xabcd].pack("Q<"))
        end
        it "stores hash_nbucket at +0xa8" do
          expect(emu).to write_to(module_object + 0xa8, [0x1234].pack("Q<"))
        end
        it "stores hash_bucket_ptr at +0x50" do
          expect(emu).to write_to(module_object + 0x50, [nso + @hash_section.nso_location + 8].pack("Q<"))
        end
        it "stores hash_chain_ptr at +0x58" do
          expect(emu).to write_to(module_object + 0x58, [nso + @hash_section.nso_location + 8 + (0x1234 * 4)].pack("Q<"))
        end
      end
    end
  end
end
