#!/usr/bin/env node
import { GoogleGenerativeAI } from '@google/generative-ai'
import { GoogleAIFileManager } from '@google/generative-ai/server'
import { Server } from '@modelcontextprotocol/sdk/server/index.js'
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js'
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js'
import fs from 'node:fs/promises'
import os from 'node:os'
import path from 'node:path'

const apiKey = process.env.GEMINI_API_KEY
if (!apiKey) {
  console.error('❌ GEMINI_API_KEY environment variable is required')
  console.error('')
  console.error('To fix this:')
  console.error('')
  console.error('1. Get your API key from: https://aistudio.google.com/apikey')
  console.error('')
  console.error('2. Add to your shell profile:')
  console.error('   For macOS/Linux (add to ~/.zshrc or ~/.bashrc):')
  console.error("   export GEMINI_API_KEY='your-actual-api-key-here'")
  console.error('')
  console.error('   For Windows PowerShell:')
  console.error(
    "   [System.Environment]::SetEnvironmentVariable('GEMINI_API_KEY', 'your-key', 'User')",
  )
  console.error('')
  console.error('3. Reload your terminal:')
  console.error('   source ~/.zshrc  (or source ~/.bashrc)')
  console.error('')
  console.error('4. Restart Claude Code')
  console.error('')
  console.error('For detailed instructions, see GEMINI_VISION_SETUP.md')
  process.exit(1)
}

const genAI = new GoogleGenerativeAI(apiKey)
const fileManager = new GoogleAIFileManager(apiKey)
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' })

// Expand home directory in paths
function expandPath(filepath) {
  if (filepath.startsWith('~/')) {
    return path.join(os.homedir(), filepath.slice(2))
  }
  return filepath
}

// Helper function to wait/sleep
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

// Upload file to Gemini
async function uploadFile(filePath) {
  const expandedPath = expandPath(filePath)

  try {
    await fs.access(expandedPath)
  } catch {
    throw new Error(`File not found: ${filePath}`)
  }

  const ext = path.extname(expandedPath).toLowerCase()
  const mimeTypes = {
    '.bmp': 'image/bmp',
    '.doc': 'application/msword',
    '.docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.gif': 'image/gif',
    '.jpeg': 'image/jpeg',
    '.jpg': 'image/jpeg',
    '.odt': 'application/vnd.oasis.opendocument.text',
    '.pdf': 'application/pdf',
    '.png': 'image/png',
    '.rtf': 'application/rtf',
    '.txt': 'text/plain',
    '.webp': 'image/webp',
    // Video formats
    '.3gp': 'video/3gpp',
    '.avi': 'video/x-msvideo',
    '.flv': 'video/x-flv',
    '.m4v': 'video/x-m4v',
    '.mkv': 'video/x-matroska',
    '.mov': 'video/quicktime',
    '.mp4': 'video/mp4',
    '.webm': 'video/webm',
    '.wmv': 'video/x-ms-wmv',
  }

  const uploadResult = await fileManager.uploadFile(expandedPath, {
    mimeType: mimeTypes[ext] || 'application/octet-stream',
  })

  let file = uploadResult.file

  // For video files, poll until the file is in ACTIVE state
  const videoExtensions = [
    '.mp4',
    '.avi',
    '.mov',
    '.webm',
    '.mkv',
    '.wmv',
    '.flv',
    '.3gp',
    '.m4v',
  ]
  if (videoExtensions.includes(ext)) {
    console.error(
      `Waiting for video file to process: ${path.basename(filePath)}`,
    )
    let attempts = 0
    const maxAttempts = 60 // Max 5 minutes (60 * 5 seconds)

    while (file.state !== 'ACTIVE' && attempts < maxAttempts) {
      await sleep(5000) // Wait 5 seconds
      attempts++

      // Get updated file status
      const fileStatus = await fileManager.getFile(file.name)
      file = fileStatus

      console.error(
        `Video processing status: ${file.state} (attempt ${attempts}/${maxAttempts})`,
      )

      if (file.state === 'FAILED') {
        throw new Error(`Video processing failed for: ${filePath}`)
      }
    }

    if (file.state !== 'ACTIVE') {
      throw new Error(
        `Video processing timeout for: ${filePath}. File state: ${file.state}`,
      )
    }

    console.error('Video file is ready for analysis')
  }

  return file
}

// Tool handlers
async function analyzeDocument(args) {
  const documentPath = args.document_path
  const prompt =
    args.prompt || 'Analyze this document and provide a comprehensive summary'

  const file = await uploadFile(documentPath)
  const result = await model.generateContent([
    prompt,
    { fileData: { fileUri: file.uri, mimeType: file.mimeType } },
  ])

  return result.response.text()
}

async function analyzeImage(args) {
  const imagePath = args.image_path
  const prompt = args.prompt || 'Describe this image in detail'

  const file = await uploadFile(imagePath)
  const result = await model.generateContent([
    prompt,
    { fileData: { fileUri: file.uri, mimeType: file.mimeType } },
  ])

  return result.response.text()
}

async function analyzeMultiple(args) {
  const imagePaths = args.image_paths
  const prompt = args.prompt || 'Analyze these images'

  const content = [prompt]
  for (const imagePath of imagePaths) {
    const file = await uploadFile(imagePath)
    content.push({ fileData: { fileUri: file.uri, mimeType: file.mimeType } })
  }

  const result = await model.generateContent(content)
  return result.response.text()
}

async function compareImages(args) {
  const image1Path = args.image1_path
  const image2Path = args.image2_path
  const focus = args.focus || 'differences'

  const prompts = {
    changes: 'Describe what has changed between the first and second image.',
    differences:
      'Compare these two images and describe all the differences you can find.',
    similarities:
      'Compare these two images and describe what they have in common.',
  }

  const [file1, file2] = await Promise.all([
    uploadFile(image1Path),
    uploadFile(image2Path),
  ])

  const result = await model.generateContent([
    prompts[focus] || prompts.differences,
    { fileData: { fileUri: file1.uri, mimeType: file1.mimeType } },
    { fileData: { fileUri: file2.uri, mimeType: file2.mimeType } },
  ])

  return result.response.text()
}

async function extractText(args) {
  const imagePath = args.image_path
  const format = args.format || 'plain'

  const prompts = {
    markdown:
      'Extract all text from this image and format it in markdown, preserving structure.',
    plain:
      'Extract and transcribe all text from this image. Return only the text, nothing else.',
    structured:
      'Extract all text from this image and organize it with clear sections and structure.',
  }

  const file = await uploadFile(imagePath)
  const result = await model.generateContent([
    prompts[format] || prompts.plain,
    { fileData: { fileUri: file.uri, mimeType: file.mimeType } },
  ])

  return result.response.text()
}

async function suggestFilename(args) {
  const imagePath = args.image_path
  const maxLength = args.max_length || 60
  const includeDate = args.include_date || false

  const prompt = `Analyze this image and suggest a descriptive filename for it.
  Requirements:
  - Maximum ${maxLength} characters (not including extension)
  - Use title case with spaces (will be converted to hyphens)
  - Be specific and descriptive about the content
  - ${includeDate ? 'Include YYYY-MM-DD prefix if a date is visible in the image' : 'Do not include date prefix'}
  - Focus on the main subject or purpose of the image
  - For screenshots: include the application or website name
  - For diagrams: include the type and subject
  - For photos: include the subject and context
  - Return ONLY the filename suggestion, no explanation or extension`

  const file = await uploadFile(imagePath)
  const result = await model.generateContent([
    prompt,
    { fileData: { fileUri: file.uri, mimeType: file.mimeType } },
  ])

  // Clean up the suggestion and format it
  let suggestion = result.response.text().trim()
  // Remove any file extension if accidentally included
  suggestion = suggestion.replace(/\.(png|jpg|jpeg|gif|webp|pdf)$/i, '')
  // Replace spaces with hyphens
  suggestion = suggestion.replace(/\s+/g, ' ').replace(/ /g, ' - ')
  // Ensure it doesn't exceed max length
  if (suggestion.length > maxLength) {
    suggestion = suggestion.substring(0, maxLength).replace(/ - $/, '')
  }

  return suggestion
}

// Analyze video files or YouTube URLs
async function analyzeVideo(args) {
  const videoPath = args.video_path
  const youtubeUrl = args.youtube_url
  const prompt =
    args.prompt ||
    'Summarize this video in detail, including key moments and any text or speech content'

  if (!videoPath && !youtubeUrl) {
    throw new Error('Either video_path or youtube_url is required')
  }

  if (videoPath && youtubeUrl) {
    throw new Error('Please provide either video_path or youtube_url, not both')
  }

  let fileData

  if (youtubeUrl) {
    // YouTube URLs can be passed directly to the API
    fileData = { fileUri: youtubeUrl }
  } else {
    // Upload local video file
    const file = await uploadFile(videoPath)
    fileData = { fileUri: file.uri, mimeType: file.mimeType }
  }

  const result = await model.generateContent([prompt, { fileData }])

  return result.response.text()
}

// Create MCP server
const server = new Server(
  { name: 'gemini-vision', version: '1.0.0' },
  { capabilities: { tools: {} } },
)

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      description:
        'Analyze an image - transcribe text, describe content, or answer questions',
      inputSchema: {
        properties: {
          image_path: { description: 'Path to the image file', type: 'string' },
          prompt: {
            default: 'Describe this image',
            description: 'What to do with the image',
            type: 'string',
          },
        },
        required: ['image_path'],
        type: 'object',
      },
      name: 'analyze_image',
    },
    {
      description: 'Analyze multiple images at once',
      inputSchema: {
        properties: {
          image_paths: {
            description: 'List of image paths',
            items: { type: 'string' },
            type: 'array',
          },
          prompt: {
            default: 'Analyze these images',
            description: 'What to do with the images',
            type: 'string',
          },
        },
        required: ['image_paths'],
        type: 'object',
      },
      name: 'analyze_multiple',
    },
    {
      description: 'Extract and transcribe all text from an image (OCR)',
      inputSchema: {
        properties: {
          format: {
            default: 'plain',
            enum: ['plain', 'markdown', 'structured'],
            type: 'string',
          },
          image_path: { description: 'Path to the image file', type: 'string' },
        },
        required: ['image_path'],
        type: 'object',
      },
      name: 'extract_text',
    },
    {
      description:
        'Compare two images and describe differences or similarities',
      inputSchema: {
        properties: {
          focus: {
            default: 'differences',
            enum: ['differences', 'similarities', 'changes'],
            type: 'string',
          },
          image1_path: { description: 'Path to first image', type: 'string' },
          image2_path: { description: 'Path to second image', type: 'string' },
        },
        required: ['image1_path', 'image2_path'],
        type: 'object',
      },
      name: 'compare_images',
    },
    {
      description:
        'Analyze an image and suggest a descriptive filename (without extension)',
      inputSchema: {
        properties: {
          image_path: { description: 'Path to the image file', type: 'string' },
          include_date: {
            default: false,
            description: 'Include date prefix in suggestion',
            type: 'boolean',
          },
          max_length: {
            default: 60,
            description: 'Maximum filename length',
            type: 'number',
          },
        },
        required: ['image_path'],
        type: 'object',
      },
      name: 'suggest_image_filename',
    },
    {
      description:
        'Analyze video files or YouTube URLs - extract content, summarize, transcribe speech, identify objects/text. Provide either video_path OR youtube_url',
      inputSchema: {
        properties: {
          prompt: {
            default: 'Summarize this video in detail',
            description: 'What to analyze in the video',
            type: 'string',
          },
          video_path: {
            description: 'Path to local video file (MP4, AVI, MOV, etc.)',
            type: 'string',
          },
          youtube_url: {
            description:
              'YouTube video URL (e.g., https://www.youtube.com/watch?v=...)',
            type: 'string',
          },
        },
        required: [],
        type: 'object',
      },
      name: 'analyze_video',
    },
    {
      description:
        'Analyze a PDF or document with custom prompts - extract specific information, find mentions of topics, summarize sections, etc.',
      inputSchema: {
        properties: {
          document_path: {
            description:
              'Path to the document file (PDF, DOC, DOCX, ODT, RTF, TXT)',
            type: 'string',
          },
          prompt: {
            default:
              'Analyze this document and provide a comprehensive summary',
            description: 'What to analyze or extract from the document',
            type: 'string',
          },
        },
        required: ['document_path'],
        type: 'object',
      },
      name: 'analyze_document',
    },
  ],
}))

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { arguments: args, name } = request.params

  try {
    let result
    switch (name) {
      case 'analyze_document':
        result = await analyzeDocument(args)
        break
      case 'analyze_image':
        result = await analyzeImage(args)
        break
      case 'analyze_multiple':
        result = await analyzeMultiple(args)
        break
      case 'analyze_video':
        result = await analyzeVideo(args)
        break
      case 'compare_images':
        result = await compareImages(args)
        break
      case 'extract_text':
        result = await extractText(args)
        break
      case 'suggest_image_filename':
        result = await suggestFilename(args)
        break
      default:
        throw new Error(`Unknown tool: ${name}`)
    }

    return {
      content: [{ text: result, type: 'text' }],
    }
  } catch (error) {
    throw new Error(`Tool execution failed: ${error.message}`)
  }
})

// Start server
async function main() {
  const transport = new StdioServerTransport()
  await server.connect(transport)
  console.error('🚀 Gemini Vision MCP Server running')
}

main().catch(console.error)
