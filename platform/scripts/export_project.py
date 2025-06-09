#!/usr/bin/env python3
"""
Atlos Project Export Script

This script exports all data from an Atlos project including:
- Incidents with all metadata
- Source material and artifacts (files)
- Comments and updates
- Organized folder structure with JSON and human-readable outputs
"""

import os
import json
import requests
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Any
from urllib.parse import urlparse
import mimetypes
import trio
from dotenv import load_dotenv

SCRIPT_VERSION = '1.0'

class AtlosExporter:
    def __init__(self, api_key: str, base_url: str = "https://platform.atlos.org"):
        self.api_key = api_key
        self.base_url = base_url.rstrip('/')
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {api_key}',
            'User-Agent': f'Atlos-Export-Script/{SCRIPT_VERSION}'
        })
        
    def _make_request(self, endpoint: str, params: Optional[Dict] = None) -> Dict:
        """Make authenticated API request"""
        url = f"{self.base_url}/api/v2/{endpoint}"
        response = self.session.get(url, params=params or {})
        response.raise_for_status()
        return response.json()
            
    def _download_file(self, url: str, filepath: Path) -> bool:
        """Download a file from URL to local filepath"""
        # Use a fresh session without auth headers for S3 downloads
        response = requests.get(url, stream=True)
        response.raise_for_status()
        
        filepath.parent.mkdir(parents=True, exist_ok=True)
        with open(filepath, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return True
            
    def _paginate_all(self, endpoint: str, params: Optional[Dict] = None) -> List[Dict]:
        """Fetch all results from a paginated endpoint"""
        all_results = []
        cursor = None
        
        while True:
            request_params = params.copy() if params else {}
            if cursor:
                request_params['cursor'] = cursor
                
            data = self._make_request(endpoint, request_params)
            results = data.get('results', [])
            all_results.extend(results)
            
            cursor = data.get('next')
            if not cursor:
                break
                
            print(f"Fetched {len(all_results)} items from {endpoint}...")
            
        return all_results
        
    def fetch_incidents(self) -> List[Dict]:
        """Fetch all incidents in the project"""
        print("Fetching incidents...")
        return self._paginate_all('incidents')
        
    def fetch_source_material(self) -> List[Dict]:
        """Fetch all source material in the project"""
        print("Fetching source material...")
        return self._paginate_all('source_material')
        
    def fetch_updates(self, incident_slug: Optional[str] = None) -> List[Dict]:
        """Fetch updates/comments, optionally filtered by incident"""
        endpoint = 'updates'
        params = {'slug': incident_slug} if incident_slug else None
        return self._paginate_all(endpoint, params)
        
    def fetch_all_updates(self) -> List[Dict]:
        """Fetch all updates/comments in the project"""
        print("Fetching all updates and comments...")
        return self._paginate_all('updates')
        
    def export_project(self, output_dir: Path):
        """Export entire project to structured directory"""
        output_dir = Path(output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"Starting export to {output_dir}")
        
        # Create export metadata
        export_info = {
            'export_timestamp': datetime.now().isoformat(),
            'base_url': self.base_url,
            'script_version': SCRIPT_VERSION
        }
        
        # Fetch all data
        print("\n=== Fetching Data ===")
        incidents = self.fetch_incidents()
        source_material = self.fetch_source_material()
        all_updates = self.fetch_all_updates()
        
        print(f"Found {len(incidents)} incidents")
        print(f"Found {len(source_material)} source material items")
        print(f"Found {len(all_updates)} updates/comments")
        
        # Create data structures
        print("\n=== Organizing Data ===")
        
        # Group source material (media versions) by incident (media)
        source_by_incident = {}
        for sm in source_material:
            media_id = sm.get('incident_id')
            if media_id not in source_by_incident:
                source_by_incident[media_id] = []    
            source_by_incident[media_id].append(sm)
                
        # Group updates (comments) by incident (media)  
        # media_id in updates directly refers to the incident ID
        updates_by_incident = {}
        for update in all_updates:
            media_id = update.get('media_id')  # This is the incident ID
            if media_id not in updates_by_incident:
                updates_by_incident[media_id] = []
            updates_by_incident[media_id].append(update)
        
        # Create main export structure
        export_data = {
            'export_info': export_info,
            'incidents': incidents,
            'source_material': source_material,
            'updates': all_updates,
            'summary': {
                'total_incidents': len(incidents),
                'total_source_material': len(source_material),
                'total_updates': len(all_updates)
            }
        }
        
        # Save main export JSON
        with open(output_dir / 'export_data.json', 'w') as f:
            json.dump(export_data, f, indent=2, ensure_ascii=False)
            
        # Create incidents directory
        incidents_dir = output_dir / 'incidents'
        incidents_dir.mkdir(exist_ok=True)
        
        print("\n=== Processing Incidents ===")
        
        def process_incident(incident):
            incident_slug = incident['slug']
            incident_id = incident['id']
            
            print(f"Processing incident {incident_slug}")
            
            # Create incident directory
            incident_dir = incidents_dir / incident_slug
            incident_dir.mkdir(exist_ok=True)
            
            # Get related data  
            incident_source_material = source_by_incident.get(incident_id)  # media versions for this media (incident)
            incident_comments = updates_by_incident.get(incident_id)  # comments for this media (incident)
            
            # Create comprehensive incident data
            incident_data = {
                'incident': incident,
                'source_material': incident_source_material,  # media versions
                'comments': incident_comments,  # updates = comments
                'summary': {
                    'source_material_count': len(incident_source_material),
                    'comments_count': len(incident_comments),
                    'artifacts_count': sum(len(sm.get('artifacts', [])) for sm in incident_source_material)
                }
            }
            
            # Save incident JSON
            with open(incident_dir / 'incident_data.json', 'w') as f:
                json.dump(incident_data, f, indent=2, ensure_ascii=False)
                
            # Create human-readable summary
            self._create_incident_summary(incident_dir / 'README.md', incident_data)
            
            # Download artifacts from source material
            if incident_source_material:
                artifacts_dir = incident_dir / 'source_material_files'
                self._download_artifacts(incident_source_material, artifacts_dir)
                
            # Download comment attachments
            if incident_comments:
                comments_with_attachments = [c for c in incident_comments if c.get('attachment_urls')]
                if comments_with_attachments:
                    attachments_dir = incident_dir / 'comment_attachments'
                    self._download_comment_attachments(comments_with_attachments, attachments_dir)
        
        async def process_incidents():
            async with trio.open_nursery() as nursery:
                limiter = trio.CapacityLimiter(20)  # max 20 incidents at a time
                async def process_incident_async_wrapper(incident):
                    async with limiter:
                        await trio.to_thread.run_sync(process_incident, incident)
                
                for incident in incidents:
                    nursery.start_soon(process_incident_async_wrapper, incident)
        
        trio.run(process_incidents)

        # Create overall project summary
        self._create_project_summary(output_dir / 'README.md', export_data)
        
        print(f"\n=== Export Complete ===")
        print(f"Export saved to: {output_dir.absolute()}")
        
    def _download_artifacts(self, source_material: List[Dict], artifacts_dir: Path):
        """Download all artifacts for source material"""
        artifacts_dir.mkdir(exist_ok=True)
        
        for sm in source_material:
            sm_id = sm['id']
            artifacts = sm['artifacts']
            
            if not artifacts:
                continue
                
            sm_dir = artifacts_dir / f"source_{sm_id[:8]}"
            sm_dir.mkdir(exist_ok=True)
            
            print(f"  Processing source material {sm_id[:8]} with {len(artifacts)} artifacts")
            
            for artifact in artifacts:
                file_url = artifact['access_url']
                
                # Create meaningful filename based on artifact type and metadata
                artifact_type = artifact['type']
                artifact_id = artifact['id'][:8]
                mime_type = artifact['mime_type']
                title = artifact.get('title', '')
                
                # Determine file extension from mime type
                ext = mimetypes.guess_extension(mime_type) or ''
                
                # Build filename: type_id_title.ext
                filename_parts = [artifact_type, artifact_id]
                if title:
                    # Clean title for filename
                    clean_title = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_')).strip()
                    if clean_title:
                        filename_parts.append(clean_title[:20])
                        
                filename = "_".join(filename_parts) + ext
                filepath = sm_dir / filename
                
                print(f"    Downloading: {filename} ({artifact['file_size']} bytes)")
                self._download_file(file_url, filepath)
                
                # Save artifact metadata
                metadata = {
                    'artifact_info': artifact,
                    'local_filename': filename,
                    'media_version_id': sm_id,  # This is source material (media version)
                    'original_url': file_url
                }
                    
                metadata_file = sm_dir / f"{filename}.metadata.json"
                with open(metadata_file, 'w') as f:
                    json.dump(metadata, f, indent=2)
                    
    def _download_comment_attachments(self, updates: List[Dict], attachments_dir: Path):
        """Download all files attached to comments/updates"""
        attachments_dir.mkdir(exist_ok=True)
        
        for update in updates:
            if not update['attachment_urls']:
                continue
                
            update_id = update['id'][:8]
            user = update['user']['username']
            timestamp = update['inserted_at'][:10]  # Just date part
            
            update_dir = attachments_dir / f"{timestamp}_{user}_{update_id}"
            update_dir.mkdir(exist_ok=True)
            
            print(f"  Processing comment attachments for {user} on {timestamp}")
            
            attachment_urls = update['attachment_urls']
            attachment_names = update['attachments']
            
            for i, url in enumerate(attachment_urls):
                # Use original filename if available
                if i < len(attachment_names):
                    original_name = attachment_names[i]
                else:
                    parsed_url = urlparse(url)
                    original_name = os.path.basename(parsed_url.path)
                
                # Clean filename
                filename = "".join(c for c in original_name if c.isalnum() or c in (' ', '-', '_', '.')).strip()
                filepath = update_dir / filename
                
                print(f"    Downloading: {filename}")
                self._download_file(url, filepath)
                
                # Save attachment metadata
                metadata = {
                    'comment_info': {  # update = comment
                        'id': update['id'],
                        'type': update['type'],
                        'user': user,
                        'timestamp': update['inserted_at'],
                        'message': update['explanation']
                    },
                    'local_filename': filename,
                    'original_url': url
                }
                    
                metadata_file = update_dir / f"{filename}.metadata.json"
                with open(metadata_file, 'w') as f:
                    json.dump(metadata, f, indent=2)
                    
    def _create_incident_summary(self, filepath: Path, incident_data: Dict):
        """Create human-readable incident summary"""
        incident = incident_data['incident']
        source_material = incident_data['source_material']  # media versions
        comments = incident_data['comments']  # updates = comments
        
        with open(filepath, 'w') as f:
            f.write(f"# Incident {incident['slug']}\n\n")
            
            # Basic info
            f.write("## Overview\n")
            f.write(f"**Description:** {incident.get('description', 'No description')}\n\n")
            f.write(f"**Status:** {incident.get('status', 'Unknown')}\n\n")
            f.write(f"**Created:** {incident['inserted_at']}\n\n")
            f.write(f"**Updated:** {incident['updated_at']}\n\n")
            
            # Attributes (all the attr_* fields)
            attr_fields = {k: v for k, v in incident.items() if k.startswith('attr_')}
            if attr_fields:
                f.write("## Attributes\n")
                for key, value in attr_fields.items():
                    clean_key = key.replace('attr_', '').replace('_', ' ').title()
                    f.write(f"- **{clean_key}:** {value}\n")
                f.write("\n")
            
            # Source Material
            if source_material:
                f.write(f"## Source Material ({len(source_material)} items)\n\n")
                for sm in source_material:
                    sm_id = sm['id'][:8]
                    f.write(f"### Source Material {sm_id}\n")
                    if sm.get('source_url'):
                        f.write(f"**URL:** {sm['source_url']}\n\n")
                    
                    artifacts = sm['artifacts']
                    if artifacts:
                        f.write(f"**Files ({len(artifacts)} artifacts):**\n")
                        for artifact in artifacts:
                            artifact_type = artifact['type']
                            file_size = artifact['file_size']
                            mime_type = artifact['mime_type']
                            title = artifact.get('title', 'Untitled')
                            f.write(f"- {artifact_type}: {title} ({file_size} bytes, {mime_type})\n")
                        f.write("\n")
            
            # Comments (Updates)
            if comments:
                f.write(f"## Comments and Updates ({len(comments)} items)\n\n")
                for update in comments:  # keeping 'update' variable name for consistency
                    timestamp = update['inserted_at']
                    user = update['user']['username'] if update['user'] else 'System'
                    update_type = update['type']
                    
                    # Check for attachments
                    has_attachments = bool(update.get('attachment_urls'))
                    attachment_indicator = " 📎" if has_attachments else ""
                    
                    f.write(f"### {timestamp} - {user} ({update_type}{attachment_indicator})\n")
                    
                    if update_type == 'comment':
                        message = update['explanation']
                        f.write(f"**Comment:** {message}\n")
                        
                        # Show attachments if any
                        attachments = update.get('attachments', [])
                        if attachments:
                            f.write(f"**Attachments:** {', '.join(attachments)}\n")
                        f.write("\n")
                    else:
                        # For other update types, show what changed
                        explanation = update['explanation']
                        modified_attr = update.get('modified_attribute')
                        new_value = update.get('new_value')
                        
                        if modified_attr and new_value is not None:
                            f.write(f"**Updated {modified_attr}:** {new_value}\n")
                        if explanation:
                            f.write(f"**Note:** {explanation}\n")
                        f.write("\n")
                        
    def _create_project_summary(self, filepath: Path, export_data: Dict):
        """Create human-readable project summary"""
        summary = export_data['summary']
        
        with open(filepath, 'w') as f:
            f.write("# Atlos Project Export\n\n")
            f.write(f"Export completed: {export_data['export_info']['export_timestamp']}\n\n")
            
            f.write("## Summary\n")
            f.write(f"- **Total Incidents:** {summary['total_incidents']}\n")
            f.write(f"- **Total Source Material:** {summary['total_source_material']}\n")
            f.write(f"- **Total Updates/Comments:** {summary['total_updates']}\n\n")
            
            f.write("## Structure\n")
            f.write("```\n")
            f.write("export/\n")
            f.write("├── README.md                 # This file\n")
            f.write("├── export_data.json          # Complete export in JSON format\n")
            f.write("└── incidents/                # Individual incident folders\n")
            f.write("    └── [INCIDENT_SLUG]/      # One folder per incident\n")
            f.write("        ├── README.md         # Human-readable incident summary\n")
            f.write("        ├── incident_data.json     # Complete incident data\n")
            f.write("        ├── source_material_files/ # Files from source material\n")
            f.write("        │   └── source_[ID]/       # Grouped by source material\n")
            f.write("        └── comment_attachments/   # Files attached to comments\n")
            f.write("            └── [DATE]_[USER]_[ID]/ # Grouped by comment\n")
            f.write("```\n\n")

def main():
    parser = argparse.ArgumentParser(description='Export Atlos project data')
    parser.add_argument('--output', '-o', default='./export', 
                       help='Output directory (default: ./export)')
    parser.add_argument('--base-url', default='https://gap.atlos.org',
                       help='Atlos instance URL (default: gap.atlos.org)')
    
    args = parser.parse_args()
    
    # Load environment variables
    load_dotenv()
    api_key = os.getenv('API_KEY')
    
    if not api_key:
        print("Error: API_KEY not found in environment variables or .env file")
        exit(1)
        
    print(f"Using API key: {api_key[:10]}...")
    print(f"Connecting to: {args.base_url}")
    
    exporter = AtlosExporter(api_key, args.base_url)
    
    # Let it fail loud - no exception handling
    exporter.export_project(Path(args.output))

if __name__ == '__main__':
    main()