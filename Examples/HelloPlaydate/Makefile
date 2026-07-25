REPO_ROOT := $(shell git rev-parse --show-toplevel)
PRODUCT := HelloPlaydate.pdx
include $(REPO_ROOT)/Examples/swift.mk

# MARK: - Build PlayDate Wrapper Swift Module
build/Modules/playdate_device.o: $(REPO_ROOT)/Sources/PlayDate/*.swift
	@mkdir -p build/Modules
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_DEVICE) -c $^ -emit-module -o $@

build/Modules/playdate_simulator.o: $(REPO_ROOT)/Sources/PlayDate/*.swift
	@mkdir -p build/Modules
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_SIMULATOR) -c $^ -emit-module -o $@

# MARK: - Build Game Swift Object
# The wrapper module is a normal prerequisite so wrapper edits also rebuild
# the game object; only the Swift sources are compiler inputs.
build/game_device.o: Sources/HelloPlaydate/*.swift build/Modules/playdate_device.o
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_DEVICE) -c $(filter %.swift,$^) -o $@
$(OBJDIR)/pdex.elf: build/game_device.o
OBJS += build/game_device.o
# The wrapper object carries symbols that are not emitted into the game
# object, such as the posix_memalign shim the Embedded Swift runtime needs.
# common.mk expanded OBJS before this line, so the link prerequisite has to
# be added explicitly as well.
$(OBJDIR)/pdex.elf: build/Modules/playdate_device.o
OBJS += build/Modules/playdate_device.o

build/game_simulator.o: Sources/HelloPlaydate/*.swift build/Modules/playdate_simulator.o
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_SIMULATOR) -c $(filter %.swift,$^) -o $@
$(OBJDIR)/pdex.${DYLIB_EXT}: build/game_simulator.o
SIMCOMPILER += build/game_simulator.o