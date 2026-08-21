TARGET = FreeFireInjector.dylib
CC = clang++
CFLAGS = -arch arm64 -dynamiclib -std=c++17 -fobjc-arc -isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) -miphoneos-version-min=15.0

all: $(TARGET)

$(TARGET): Kernel/ExternalPatcher.mm Include/GameOffsets.h
	$(CC) $(CFLAGS) Kernel/ExternalPatcher.mm -o $(TARGET) -framework Foundation -framework UIKit
	@echo "Build da Dylib concluído com sucesso!"

clean:
	rm -f $(TARGET)
