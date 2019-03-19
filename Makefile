OBJECTS := crt0.o memset.o svc.o
SOURCE_ROOT := src
BUILD_DIR := build

# llvm programs

# On MacOS, brew refuses to install clang5/llvm5 in a global place. As a result,
# they have to muck around with changing the path, which sucks.
# Let's make their lives easier by asking brew where LLVM_CONFIG is.
ifeq ($(shell uname -s),Darwin)
    ifeq ($(shell brew --prefix llvm),)
        $(error need llvm installed via brew)
    else
        LLVM_CONFIG := $(shell brew --prefix llvm)/bin/llvm-config
    endif
else
    LLVM_CONFIG := llvm-config$(LLVM_POSTFIX)
endif

LLVM_BINDIR := $(shell $(LLVM_CONFIG) --bindir)
ifeq ($(LLVM_BINDIR),)
  $(error llvm-config needs to be installed)
endif

LD := $(LLVM_BINDIR)/ld.lld
CC := $(LLVM_BINDIR)/clang
CXX := $(LLVM_BINDIR)/clang++
AS := $(LLVM_BINDIR)/llvm-mc
AR := $(LLVM_BINDIR)/llvm-ar
RANLIB := $(LLVM_BINDIR)/llvm-ranlib

# linker flags for building main binary
#   -Bsymbolic: bind symbols locally
#   --shared: build a shared object
LD_FLAGS := -Bsymbolic \
	--shared \
	--gc-sections \

CC_FLAGS := -g -fPIE -fno-exceptions -fuse-ld=lld -fstack-protector-strong -O3 -mtune=cortex-a57 -target aarch64-none-linux-gnu -nostdlib -nostdlibinc -D__SWITCH__=1 -Wno-unused-command-line-argument
CXX_FLAGS := $(CPP_INCLUDES) $(CC_FLAGS) -std=c++17 -stdlib=libc++ -nodefaultlibs -nostdinc++
AR_FLAGS := rcs
AS_FLAGS := -arch=aarch64 -triple aarch64-none-switch

# for compatiblity
CFLAGS := $(CC_FLAGS)
CXXFLAGS := $(CXX_FLAGS)

all: build test

build: $(BUILD_DIR)/freertld.nso

test: build
	RTLD=$(BUILD_DIR)/freertld.nso bundle exec rspec

$(BUILD_DIR)/freertld.nso: $(BUILD_DIR)/freertld.elf
	elf2nso $< $@

$(BUILD_DIR)/freertld.elf: $(addprefix $(BUILD_DIR)/,$(OBJECTS)) link.T
	$(LD) $(LD_FLAGS) -o $@ $^

$(BUILD_DIR)/%.o: $(SOURCE_ROOT)/%.s
	mkdir -p $(@D)
	$(AS) $(AS_FLAGS) $< -filetype=obj -o $(BUILD_DIR)/$*.o

$(BUILD_DIR)/%.cpp: $(SOURCE_ROOT)/%.cpp
	mkdir -p $(@D)
	$(CXX) $(CXX_FLAGS) -Iinclude -c -o $(BUILD_DIR)/$*.o $<
