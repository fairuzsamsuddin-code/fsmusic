#!/usr/bin/env bash
# FS Music — keep trying to create the free Oracle Cloud server until capacity frees up.
#
# Run it in Oracle Cloud Shell (the  >_  icon at the top of the Oracle Cloud console):
#
#   bash <(curl -fsSL https://fairuzsamsuddin-code.github.io/fsmusic/server/oracle-retry.sh)
#
# It tries the free ARM server (VM.Standard.A1.Flex, 1 CPU / 4 GB) and the free AMD server
# (VM.Standard.E2.1.Micro) in every availability domain, once a minute, and stops as soon as
# one is created. Only Always Free shapes are used. Safe to run again at any time.
#
# Options (put before "bash"):  SHAPES=arm  or  SHAPES=amd  to try only one type.
set -uo pipefail

NAME="fsmusic"
SHAPES="${SHAPES:-both}"
WAIT="${WAIT:-60}"
KEYFILE="$HOME/fsmusic-ssh.pub"

say()  { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31mxx  %s\033[0m\n' "$*"; exit 1; }
ask()  { local a; read -r -p "$1" a </dev/tty; printf '%s' "$a"; }
nonnull() { [ -n "$1" ] && [ "$1" != "null" ]; }

command -v oci >/dev/null || die "Run this in Oracle Cloud Shell (the >_ icon at the top of the Oracle Cloud console)."

# ---------------------------------------------------------------- account
C="${OCI_TENANCY:-}"
if ! nonnull "$C"; then
  warn "Couldn't detect your tenancy automatically."
  echo "Find it in the console: profile icon (top right) → Tenancy → OCID → Copy."
  C="$(ask 'Paste your tenancy OCID: ')"
fi
[[ "$C" == ocid1.tenancy.* ]] || die "That doesn't look like a tenancy OCID (it starts with ocid1.tenancy.)."

# Already done?
show_ip() {
  local ip
  ip="$(oci compute instance list-vnics --instance-id "$1" --query 'data[0]."public-ip"' --raw-output 2>/dev/null)"
  echo
  echo "────────────────────────────────────────────────────────────"
  printf '  \033[1;32mYour free server is ready!\033[0m\n\n'
  if nonnull "$ip"; then
    printf '  Public IP address:  \033[1;36m%s\033[0m\n\n' "$ip"
  else
    printf '  It has no public IP yet: open it in the console → Networking → VNIC →\n'
    printf '  IP administration → Edit → Ephemeral public IP.\n\n'
  fi
  echo "  Next: in Termius, add a host with this address, username  ubuntu"
  echo "  and your fsmusic key, then continue with step 5 of the guide."
  echo "────────────────────────────────────────────────────────────"
}
existing="$(oci compute instance list -c "$C" --display-name "$NAME" --lifecycle-state RUNNING --query 'data[0].id' --raw-output 2>/dev/null)"
if nonnull "$existing"; then
  say "You already have a running '$NAME' server."
  show_ip "$existing"; exit 0
fi

# ---------------------------------------------------------------- SSH key
if [ ! -s "$KEYFILE" ]; then
  say "Paste the PUBLIC key from Termius (Keychain → fsmusic → Copy public key)."
  echo "It starts with ssh-ed25519 or ssh-rsa. Paste it, then press return:"
  key="$(ask '> ')"
  [[ "$key" =~ ^(ssh-(ed25519|rsa)|ecdsa-sha2-) ]] || die "That doesn't look like a public key. Copy the PUBLIC key from Termius and run this again."
  printf '%s\n' "$key" > "$KEYFILE"
fi

# ---------------------------------------------------------------- network
say "Checking your network…"
SUBNET="$(oci network subnet list -c "$C" --all \
  --query 'data[?"prohibit-public-ip-on-vnic"==`false` && "lifecycle-state"==`AVAILABLE`].id | [0]' --raw-output 2>/dev/null)"
if ! nonnull "$SUBNET"; then
  say "Creating a network with internet access (one-time, about a minute)…"
  VCN="$(oci network vcn create -c "$C" --cidr-block 10.0.0.0/16 --display-name fsmusic-vcn --dns-label fsmusic \
    --wait-for-state AVAILABLE --query 'data.id' --raw-output)" || die "Couldn't create the network."
  IGW="$(oci network internet-gateway create -c "$C" --vcn-id "$VCN" --is-enabled true --display-name fsmusic-igw \
    --wait-for-state AVAILABLE --query 'data.id' --raw-output)" || die "Couldn't create the internet gateway."
  RT="$(oci network vcn get --vcn-id "$VCN" --query 'data."default-route-table-id"' --raw-output)"
  oci network route-table update --rt-id "$RT" --force --wait-for-state AVAILABLE \
    --route-rules "[{\"destination\":\"0.0.0.0/0\",\"destinationType\":\"CIDR_BLOCK\",\"networkEntityId\":\"$IGW\"}]" >/dev/null \
    || die "Couldn't set up internet routing."
  SUBNET="$(oci network subnet create -c "$C" --vcn-id "$VCN" --cidr-block 10.0.0.0/24 --display-name fsmusic-public \
    --dns-label pub --prohibit-public-ip-on-vnic false --wait-for-state AVAILABLE --query 'data.id' --raw-output)" \
    || die "Couldn't create the subnet."
fi
echo "Using public subnet: ${SUBNET:0:40}…"

# ---------------------------------------------------------------- shapes & images
mapfile -t ADS < <(oci iam availability-domain list -c "$C" --query 'data[].name' --raw-output | python3 -c 'import sys,json; print("\n".join(json.load(sys.stdin)))')
[ "${#ADS[@]}" -gt 0 ] || die "Couldn't list availability domains."

image_for() {
  oci compute image list -c "$C" --operating-system "Canonical Ubuntu" --operating-system-version "24.04" \
    --shape "$1" --sort-by TIMECREATED --sort-order DESC --limit 1 --query 'data[0].id' --raw-output 2>/dev/null
}
TRY=()
if [ "$SHAPES" != "amd" ]; then
  IMG_ARM="$(image_for VM.Standard.A1.Flex)"; nonnull "$IMG_ARM" && TRY+=("arm") || warn "No Ubuntu 24.04 ARM image found; skipping ARM."
fi
if [ "$SHAPES" != "arm" ]; then
  IMG_AMD="$(image_for VM.Standard.E2.1.Micro)"; nonnull "$IMG_AMD" && TRY+=("amd") || warn "No Ubuntu 24.04 AMD image found; skipping AMD."
fi
[ "${#TRY[@]}" -gt 0 ] || die "No usable Ubuntu image found."

launch() {   # $1 = arm|amd, $2 = availability domain
  local args=(compute instance launch -c "$C" --availability-domain "$2" --subnet-id "$SUBNET" --assign-public-ip true
              --display-name "$NAME" --ssh-authorized-keys-file "$KEYFILE" --wait-for-state RUNNING --max-wait-seconds 900
              --query 'data.id' --raw-output)
  if [ "$1" = arm ]; then
    oci "${args[@]}" --shape VM.Standard.A1.Flex --shape-config '{"ocpus":1,"memoryInGBs":4}' --image-id "$IMG_ARM"
  else
    oci "${args[@]}" --shape VM.Standard.E2.1.Micro --image-id "$IMG_AMD"
  fi
}

# ---------------------------------------------------------------- retry loop
say "Trying to create your free server. This can take minutes or hours."
echo "Keep this tab open and your phone awake (plug it in; Settings → Display → Auto-Lock → Never)."
echo "If the window disconnects, open Cloud Shell again and run the same line — it picks up where it left off."
attempt=0
while true; do
  attempt=$((attempt + 1))
  for kind in "${TRY[@]}"; do
    for ad in "${ADS[@]}"; do
      label="$([ "$kind" = arm ] && echo 'ARM (A1.Flex 1 CPU/4 GB)' || echo 'AMD (E2.1.Micro)')"
      printf '[%s] attempt %d · %s · %s … ' "$(date +%H:%M)" "$attempt" "$label" "${ad##*:}"
      out="$(launch "$kind" "$ad" 2>&1)"; rc=$?
      if [ $rc -eq 0 ] && [[ "$out" == ocid1.instance.* ]]; then
        printf '\033[1;32mcreated!\033[0m\n'
        show_ip "$(printf '%s' "$out" | tail -1)"; exit 0
      fi
      if grep -qi 'capacity' <<<"$out"; then echo "no capacity"
      elif grep -qi -E 'TooManyRequests|429' <<<"$out"; then echo "rate limited, slowing down"; sleep 60
      elif grep -qi -E 'LimitExceeded|QuotaExceeded|service limit' <<<"$out"; then
        echo; die "Oracle says you've reached the free limit for this server type. If you already have a free server (maybe from an earlier try), delete it in Compute → Instances, or run with SHAPES=arm / SHAPES=amd."
      else
        echo "unexpected error:"; printf '%s\n' "$out" | tail -5
        # Instances that failed after being accepted can linger; clean up before retrying
        leftover="$(oci compute instance list -c "$C" --display-name "$NAME" --query 'data[?"lifecycle-state"!=`TERMINATED`].id | [0]' --raw-output 2>/dev/null)"
        if nonnull "$leftover"; then
          state="$(oci compute instance get --instance-id "$leftover" --query 'data."lifecycle-state"' --raw-output 2>/dev/null)"
          [ "$state" = RUNNING ] && { show_ip "$leftover"; exit 0; }
          warn "Removing a half-created server ($state) before retrying…"
          oci compute instance terminate --instance-id "$leftover" --force --preserve-boot-volume false >/dev/null 2>&1 || true
        fi
      fi
    done
  done
  sleep "$WAIT"
done
