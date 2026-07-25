REPO_ROOT := $(shell git rev-parse --show-toplevel)
PRODUCT := HelloPlaydate.pdx
include $(REPO_ROOT)/Examples/swift.mk

# MARK: - Build PlaydateKit Wrapper Swift Module
# The wrapper sources are organized in nested domain folders, so collect
# them recursively (a plain *.swift glob would miss the subdirectories).
PLAYDATEKIT_SOURCES := $(shell find $(REPO_ROOT)/Sources/PlaydateKit -name '*.swift')

build/Modules/playdate_device.o: $(PLAYDATEKIT_SOURCES)
	@mkdir -p build/Modules
	$(SWIFT_EXEC) $(SWIFT_FLAGS) $(SWIFT_FLAGS_DEVICE) -c $^ -emit-module -o $@

build/Modules/playdate_simulator.o: $(PLAYDATEKIT_SOURCES)
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

# MARK: - Convenience Targets
# The SDK's common.mk (included via swift.mk) already provides the build
# targets, all packaging $(PRODUCT) with pdc:
#   make             device binary + simulator dylib (alias: all)
#   make simulator   simulator dylib only
#   make device      device binary only
.PHONY: run clean-swiftpm

# Build the simulator flavor and launch the pdx in the Playdate Simulator.
run: simulator
	open -a "$(SDK)/bin/Playdate Simulator.app" $(PRODUCT)

# common.mk's clean removes the build folder, $(PRODUCT), and the binaries
# copied into Source/; also drop the .build folder SwiftPM leaves behind
# when building with build.sh.
clean: clean-swiftpm
clean-swiftpm:
	-rm -rf .build
