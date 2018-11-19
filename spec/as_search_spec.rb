require "lakebed"

ADDRESS_SPACE_BEGIN = 0x8000000

RSpec::describe "rtld" do
  describe "address space search" do
    it "calls QueryMemory starting at beginning of address space" do
      emu = Lakebed::Emulator.new
      emu.add_nso(rtld)

      expect(emu).to call_svc(6).with(:x2 => ADDRESS_SPACE_BEGIN)
    end
    
    it "hangs if QueryMemory returns a bad value" do
      emu = Lakebed::Emulator.new
      emu.add_nso(rtld)

      expect(emu).to call_svc(6).and_return(1)
      expect(emu).to halt
    end

    it "loops QueryMemory until it reaches the end of the address space" do
      emu = Lakebed::Emulator.new
      emu.add_nso(rtld)

      addr = ADDRESS_SPACE_BEGIN
      loop do
        expect(emu).to call_svc(6).with(:x2 => addr)
        addr = emu.last_query_segment[:base] + emu.last_query_segment[:size]
        if addr <= 0 then
          break
        end
      end
    end

    # TODO: test address space limits
    # A571927D65DC2BECA04492F25AE2F9D30CDBA6EB000000000000000000000000 seems to only support
    # 1.0.0's address space.
    
    it "does not attempt to locate its own MOD0" do
      emu = Lakebed::Emulator.new
      emu.add_nso(rtld)

      expect do
        addr = ADDRESS_SPACE_BEGIN
        loop do
          expect(emu).to call_svc(6).with(:x2 => addr)
          addr = emu.last_query_segment[:base] + emu.last_query_segment[:size]
          if addr <= 0 then
            break
          end
        end
      end.not_to read_from(emu, rtld + 4)
    end

    it "tries to locate MOD0 from another module" do
      emu = Lakebed::Emulator.new
      emu.add_nso(rtld)
      
      builder = Lakebed::NsoBuilder.new
      test_module = emu.add_nso(builder.build)

      expect(emu).to read_from(test_module + 4, 4)
    end
    
    it "tries to locate MOD0 from another module immediately after discovering its .text" do
      emu = Lakebed::Emulator.new
      emu.add_nso(rtld)
    
      builder = Lakebed::NsoBuilder.new
      test_module = emu.add_nso(builder.build)

      addr = ADDRESS_SPACE_BEGIN
      loop do
        expect(emu).to call_svc(6).with(:x2 => addr)
        if addr == test_module.base_addr then
          expect(emu).to read_from(test_module + 4, 4)
          break # success
        end
        addr = emu.last_query_segment[:base] + emu.last_query_segment[:size]
        if addr <= 0 then
          raise "did not probe MOD0 offset"
        end
      end
    end
    
    it "panics if MOD0 magic is invalid" do
      emu = Lakebed::Emulator.new
      emu.add_nso(rtld)
    
      builder = Lakebed::NsoBuilder.new(:mod0 => false)

      mod0_sec = builder.add_section("BAD0", :data)
      builder.add_symbol("_mod0", mod0_sec)

      test_module = emu.add_nso(builder.build)

      expect(emu).to read_from(test_module + 4, 4)
      expect(emu).to halt
    end

    it "clears the module's bss" do
      emu = Lakebed::Emulator.new
      emu.add_nso(rtld)
    
      builder = Lakebed::NsoBuilder.new
      test_module = emu.add_nso(builder.build)

      expect(emu).to read_from(test_module + 4, 4)

      bss_start = test_module.get_symbol("_bss_start")
      bss_end = test_module.get_symbol("_bss_end")

      # dirty bss to make sure it gets cleared
      emu.mu.mem_write(bss_start, "A" * (bss_end - bss_start))

      # reads module object offset after memsetting bss.
      # memset's memory access patterns are too weird
      # for me to try to predict...
      expect(emu).to read_from(test_module.get_symbol("_mod0") + 6 * 4, 4)

      # make sure it's actually cleared
      expect(emu.mu.mem_read(bss_start, bss_end - bss_start)).to eq(0.chr * (bss_end - bss_start))
    end
  end
end
