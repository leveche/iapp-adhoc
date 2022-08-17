include /etc/default/libnss-db

DATABASES = $(wildcard $(addprefix $(ETC)/,$(DBS)))

all: $(patsubst %,$(VAR_DB)/%.db,$(notdir $(DATABASES)))

$(VAR_DB)/group.db: $(VAR_DB)/group
        @$(AWK) 'BEGIN { FS=":"; OFS=":"; cnt=0 } \
                 /^[ \t]*$$/ { next } \
                 /^[ \t]*#/ { next } \
                 { printf "0%u ", cnt++; print } \
                 /^[^#]/ { printf ".%s ", $$1; print; \
                           printf "=%s ", $$3; print }' $^ | \
        (umask 022 && $(MAKEDB) -o $@ -)
