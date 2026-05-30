import argparse
import os
import sys
from io import BytesIO

try:
    import pycdlib
except ImportError:
    print("Error: pycdlib is not installed. Run 'pip install pycdlib' first.", file=sys.stderr)
    sys.exit(1)

def main():
    parser = argparse.ArgumentParser(description="Generate cloud-init cidata ISO using pycdlib")
    parser.add_argument("--hostname", required=True, help="Hostname for the instance")
    parser.add_argument("--pubkey-file", required=True, help="Path to SSH public key file")
    parser.add_argument("--output", required=True, help="Path to output ISO file")
    args = parser.parse_args()

    if not os.path.exists(args.pubkey-file if hasattr(args, 'pubkey-file') else args.pubkey_file):
        pubkey_path = args.pubkey_file
        print(f"Error: SSH public key file not found: {pubkey_path}", file=sys.stderr)
        sys.exit(1)
    else:
        pubkey_path = args.pubkey_file

    with open(pubkey_path, "r", encoding="utf-8") as f:
        ssh_key = f.read().strip()

    # Generate user-data
    user_data = f"""#cloud-config
users:
  - name: ansible
    ssh-authorized-keys:
      - {ssh_key}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
"""

    # Generate meta-data
    meta_data = f"""instance-id: iid-{args.hostname}
local-hostname: {args.hostname}
"""

    print(f"Generating {args.output} for {args.hostname}...")
    try:
        iso = pycdlib.PyCdlib()
        # Interchange level 3, vol_ident is critical and MUST be 'cidata'
        iso.new(interchange_level=3, joliet=True, rock_ridge='1.09', vol_ident='cidata')

        # Add user-data
        ud_bytes = user_data.encode('utf-8')
        iso.add_fp(
            BytesIO(ud_bytes),
            len(ud_bytes),
            '/USER_DAT.;1',
            rr_name='user-data',
            joliet_path='/user-data'
        )

        # Add meta-data
        md_bytes = meta_data.encode('utf-8')
        iso.add_fp(
            BytesIO(md_bytes),
            len(md_bytes),
            '/META_DAT.;1',
            rr_name='meta-data',
            joliet_path='/meta-data'
        )

        # Add network-config
        network_data = """version: 2
ethernets:
  enp0s3:
    dhcp4: true
  enp0s8:
    dhcp4: true
"""
        nc_bytes = network_data.encode('utf-8')
        iso.add_fp(
            BytesIO(nc_bytes),
            len(nc_bytes),
            '/NET_CONF.;1',
            rr_name='network-config',
            joliet_path='/network-config'
        )

        iso.write(args.output)
        iso.close()
        print(f"Successfully generated {args.output}")
    except Exception as e:
        print(f"Error generating ISO: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
