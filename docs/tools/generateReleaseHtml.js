/**
 * Script: Generate HTML from GitHub Release Notes
 * Author: Kami
 * Description:
 * This script automatically fetches the latest release information from the repository Loop on GitHub,
 * converts the release notes from Markdown to HTML format, and then outputs the HTML to the console.
 * 
 * Requirements:
 * - Bun: This script requires Bun to run. Bun is a modern JavaScript runtime like Node.js but faster. 
 *   Install Bun from https://bun.sh/ (https://bun.sh/docs/installation)
 *   (I recommend using it via brew, `brew install oven-sh/bun/bun`)
 * - Dependencies: This script uses `node-fetch` for making HTTP requests, `marked` for converting Markdown to HTML,
 *   and `js-beautify` for beautifying the generated HTML code.
 * 
 * Quick Start Guide:
 * 1. Install Bun by following the instructions at https://bun.sh/
 * 2. Setup Your Project (Optional):
 *    - Navigate to your project directory in the terminal.
 *    - Initialize a new project with `bun init` (if you haven't already).
 * 3. Install Dependencies:
 *    - Execute `bun add node-fetch marked js-beautify` in your terminal to install the required packages.
 * 4. Add This Script:
 *    - Save this script as `generateReleaseHtml.js` in your project directory.
 * 5. Run the Script:
 *    - Execute `bun generateReleaseHtml.js` from your terminal to run the script.
 *    - Backup command `bun run generateReleaseHtml.js`
 * 
 * Note: Ensure your system has internet access and can reach GitHub's API for this script to work properly.
 * 
 */

import fetch from 'node-fetch';
import { marked } from 'marked';
import beautify from 'js-beautify';

const releaseUrl = 'https://api.github.com/repos/MrKai77/Loop/releases/latest';
const repoUrl = 'https://github.com/MrKai77/Loop';

async function fetchReleaseData(url) {
  const response = await fetch(url, {
    headers: { 'Accept': 'application/vnd.github.v3+json' }
  });
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  return response.json();
}

function enhanceMarkdown(body) {
  return body.replace(/#(\d+)/g, (match, issueNumber) => `[${match}](${repoUrl}/issues/${issueNumber})`);
}

function generateHtml(releaseData) {
  const versionHtml = `<h1><a class="releases" href="${releaseData.html_url}">${releaseData.tag_name}</a></h1>`;
  const notesHtml = marked.parse(enhanceMarkdown(releaseData.body));
  return beautify.html(versionHtml + notesHtml, { indent_size: 2, space_in_empty_paren: true });
}

async function displayReleaseAsHtml() {
  try {
    const releaseData = await fetchReleaseData(releaseUrl);
    if (!releaseData || !releaseData.body || !releaseData.tag_name) {
      console.log('No release data found.');
      return;
    }
    console.log(generateHtml(releaseData));
  } catch (error) {
    console.error('Error processing release data:', error);
  }
}

displayReleaseAsHtml();
