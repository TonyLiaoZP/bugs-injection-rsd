#!/usr/bin/env python3
"""
Bug Injection Script for RSD Processor

This script injects bugs into the RSD processor RTL files based on bug definitions.
It creates backups of original files and can restore them when needed.
"""

import argparse
import json
import os
import sys
import shutil
from pathlib import Path
from typing import List, Dict, Any


class BugInjector:
    def __init__(self, rsd_root: Path):
        self.rsd_root = rsd_root
        self.bugs_dir = rsd_root / "bugs"
        self.backup_dir = rsd_root / ".bug_backups"
        self.state_file = self.backup_dir / "injection_state.json"

    def load_bug_definition(self, bug_id: str) -> Dict[str, Any]:
        """Load a bug definition from JSON file."""
        bug_file = self.bugs_dir / "definitions" / f"{bug_id}.json"
        if not bug_file.exists():
            raise FileNotFoundError(f"Bug definition not found: {bug_file}")

        with open(bug_file, 'r') as f:
            return json.load(f)

    def list_bugs(self) -> List[str]:
        """List all available bug definitions."""
        definitions_dir = self.bugs_dir / "definitions"
        bug_files = sorted(definitions_dir.glob("BUG_*.json"))
        bugs = []
        for bug_file in bug_files:
            with open(bug_file, 'r') as f:
                bug_def = json.load(f)
                bugs.append({
                    'id': bug_def['id'],
                    'name': bug_def['name'],
                    'category': bug_def['category'],
                    'description': bug_def['description'],
                    'severity': bug_def.get('severity', 'Unknown')
                })
        return bugs

    def backup_file(self, file_path: Path):
        """Create a backup of the original file."""
        if not self.backup_dir.exists():
            self.backup_dir.mkdir(parents=True)

        backup_path = self.backup_dir / file_path.name
        if not backup_path.exists():
            shutil.copy2(file_path, backup_path)
            print(f"  Backed up: {file_path.name}")

    def inject_bug(self, bug_id: str, dry_run: bool = False) -> bool:
        """Inject a single bug into the codebase."""
        try:
            bug_def = self.load_bug_definition(bug_id)
            file_path = self.rsd_root / bug_def['file']

            if not file_path.exists():
                print(f"ERROR: File not found: {file_path}")
                return False

            print(f"\nInjecting {bug_id}: {bug_def['name']}")
            print(f"  File: {bug_def['file']}")
            print(f"  Description: {bug_def['description']}")

            if dry_run:
                print("  [DRY RUN] Would apply patches:")
                for patch in bug_def['patches']:
                    print(f"    Line {patch['line']}: {patch['original'][:50]}...")
                return True

            # Backup original file
            self.backup_file(file_path)

            # Read file content
            with open(file_path, 'r') as f:
                lines = f.readlines()

            # Apply patches
            patches_applied = 0
            for patch in bug_def['patches']:
                line_num = patch['line'] - 1  # Convert to 0-indexed
                if line_num < 0 or line_num >= len(lines):
                    print(f"  WARNING: Line {patch['line']} out of range")
                    continue

                original = patch['original']
                buggy = patch['buggy']

                # Check if line matches original
                if original.strip() in lines[line_num].strip():
                    # Preserve indentation
                    indent = len(lines[line_num]) - len(lines[line_num].lstrip())
                    lines[line_num] = ' ' * indent + buggy + '\n'
                    patches_applied += 1
                    print(f"  Applied patch at line {patch['line']}")
                else:
                    print(f"  WARNING: Line {patch['line']} doesn't match expected content")
                    print(f"    Expected: {original[:50]}...")
                    print(f"    Found: {lines[line_num].strip()[:50]}...")

            # Write modified file
            if patches_applied > 0:
                with open(file_path, 'w') as f:
                    f.writelines(lines)
                print(f"  Successfully applied {patches_applied} patch(es)")
                return True
            else:
                print(f"  ERROR: No patches applied")
                return False

        except Exception as e:
            print(f"ERROR injecting {bug_id}: {e}")
            return False

    def restore_files(self):
        """Restore all backed up files to their original state."""
        if not self.backup_dir.exists():
            print("No backups found. Files are already clean.")
            return

        print("Restoring original files...")
        backup_files = list(self.backup_dir.glob("*.sv"))

        for backup_file in backup_files:
            # Find original file location (exclude backup directory itself)
            original_candidates = [
                p for p in self.rsd_root.rglob(backup_file.name)
                if not str(p).startswith(str(self.backup_dir))
            ]
            if not original_candidates:
                print(f"  WARNING: Could not find original location for {backup_file.name}")
                continue

            # Restore to first match (should be unique)
            original_path = original_candidates[0]
            shutil.copy2(backup_file, original_path)
            print(f"  Restored: {backup_file.name}")

        # Clean up backup directory
        shutil.rmtree(self.backup_dir)
        print("All files restored successfully.")

    def save_state(self, bug_ids: List[str]):
        """Save the current injection state."""
        if not self.backup_dir.exists():
            self.backup_dir.mkdir(parents=True)

        state = {
            'injected_bugs': bug_ids,
            'timestamp': str(Path.cwd())
        }

        with open(self.state_file, 'w') as f:
            json.dump(state, f, indent=2)

    def load_state(self) -> Dict[str, Any]:
        """Load the current injection state."""
        if not self.state_file.exists():
            return {'injected_bugs': []}

        with open(self.state_file, 'r') as f:
            return json.load(f)


def main():
    parser = argparse.ArgumentParser(
        description='Inject bugs into RSD processor for testing',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --bugs BUG_001                    # Inject single bug
  %(prog)s --bugs BUG_001 BUG_002            # Inject multiple bugs
  %(prog)s --list                            # List all available bugs
  %(prog)s --restore                         # Restore original files
  %(prog)s --bugs BUG_001 --dry-run          # Preview changes without applying
        """
    )

    parser.add_argument('--bugs', nargs='+', metavar='BUG_ID',
                        help='Bug IDs to inject (e.g., BUG_001 BUG_002)')
    parser.add_argument('--list', action='store_true',
                        help='List all available bugs')
    parser.add_argument('--restore', action='store_true',
                        help='Restore original files (remove all injected bugs)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show what would be done without making changes')
    parser.add_argument('--rsd-root', type=Path, default=Path.cwd(),
                        help='Path to RSD root directory (default: current directory)')

    args = parser.parse_args()

    # Initialize injector
    injector = BugInjector(args.rsd_root)

    # Handle list command
    if args.list:
        bugs = injector.list_bugs()
        if not bugs:
            print("No bugs found in bugs/ directory")
            return 0

        print("\nAvailable Bugs:")
        print("-" * 80)
        for bug in bugs:
            print(f"{bug['id']}: {bug['name']}")
            print(f"  Category: {bug['category']}")
            print(f"  Severity: {bug['severity']}")
            print(f"  Description: {bug['description']}")
            print()
        return 0

    # Handle restore command
    if args.restore:
        injector.restore_files()
        return 0

    # Handle bug injection
    if args.bugs:
        print(f"RSD Root: {args.rsd_root}")
        print(f"Bugs to inject: {', '.join(args.bugs)}")

        if args.dry_run:
            print("\n[DRY RUN MODE - No files will be modified]")

        success_count = 0
        for bug_id in args.bugs:
            if injector.inject_bug(bug_id, dry_run=args.dry_run):
                success_count += 1

        print(f"\n{'[DRY RUN] Would inject' if args.dry_run else 'Successfully injected'} {success_count}/{len(args.bugs)} bug(s)")

        if not args.dry_run and success_count > 0:
            injector.save_state(args.bugs)
            print("\nTo restore original files, run: python bugs/inject.py --restore")

        return 0 if success_count == len(args.bugs) else 1

    # No command specified
    parser.print_help()
    return 1


if __name__ == '__main__':
    sys.exit(main())
