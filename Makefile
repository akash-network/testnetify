BINARY_VERSION  ?= v0.22.6
CURRENT_UPGRADE ?= v0.22.0
GENESIS_ORIG    ?= genesis.json
GENESIS_DEST    ?= latest-$(CURRENT_UPGRADE).json
LZ4_ARCHIVE     := $(GENESIS_DEST).tar.lz4

BIN_DIR         := $(CACHE_BIN)/$(BINARY_VERSION)
AKASH           := $(BIN_DIR)/akash

cache_init      := $(CACHE_DIR)/.init

.PHONY: cache
cache: $(cache_init)

.PHONY: init
init: $(cache_init) $(AKASH) $(test_key)

.PRECIOUS: %/.init
%/.init:
	@echo "creating dir structure..."
	mkdir -p ${@D}
	mkdir -p $(CACHE_BIN)
	touch $@

$(AKASH): $(cache_init)
	@echo "Installing akash $(BINARY_VERSION) ..."
	mkdir -p $(BIN_DIR)
	curl -sfL https://raw.githubusercontent.com/akash-network/node/master/install.sh | bash -s -- -b $(BIN_DIR) $(BINARY_VERSION)

.PHONY: install
install: $(AKASH)

testnetify: $(AKASH)
	$(AKASH) debug testnetify $(GENESIS_ORIG) $(GENESIS_DEST) -c config-$(CURRENT_UPGRADE).json 

archive: testnetify
	tar cvf - $(GENESIS_DEST) | lz4 -f - $(LZ4_ARCHIVE)
	
.PHONY: clean
clean:
	rm -rf $(CACHE_DIR)
