import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { gate, jsonError, CORS_HEADERS } from "../_shared/gate.ts"

const DAILY_LIMIT = { free: 3, plus: 6 }
const MAX_AUDIO_BYTES = 20 * 1024 * 1024 // Whisper's own ceiling is 25 MB
const ALLOWED_HOST = "ymbfqlrarlnqtzatgfah.supabase.co"
const ALLOWED_PATH_PREFIX = "/storage/v1/object/sign/voice-recordings/"

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  const g = await gate(req, "transcribe-audio", DAILY_LIMIT)
  if (g instanceof Response) return g

  try {
    const { audioUrl } = await req.json()

    // Only signed URLs into this project's private recordings bucket may be
    // transcribed — anything else is someone else's audio on our bill.
    let parsed: URL
    try {
      parsed = new URL(audioUrl)
    } catch {
      return jsonError("Invalid audioUrl", 400)
    }
    if (parsed.protocol !== "https:" || parsed.host !== ALLOWED_HOST ||
        !parsed.pathname.startsWith(ALLOWED_PATH_PREFIX)) {
      return jsonError("audioUrl not allowed", 400)
    }

    console.log('=== Whisper Transcription Started ===')

    const apiKey = Deno.env.get('OPENAI_API_KEY')
    if (!apiKey) {
      throw new Error('OpenAI API key is not configured')
    }

    // Download the audio file
    console.log('Downloading audio file...')
    const audioResponse = await fetch(audioUrl)
    console.log('Download status:', audioResponse.status)

    if (!audioResponse.ok) {
      throw new Error(`Failed to download audio: ${audioResponse.statusText}`)
    }

    const contentLength = Number(audioResponse.headers.get('Content-Length') ?? 0)
    if (contentLength > MAX_AUDIO_BYTES) {
      return jsonError("Audio file too large", 413)
    }

    const audioBlob = await audioResponse.blob()
    console.log('Audio downloaded, size:', audioBlob.size, 'bytes')
    if (audioBlob.size > MAX_AUDIO_BYTES) {
      return jsonError("Audio file too large", 413)
    }

    // Create form data for Whisper API
    const formData = new FormData()
    formData.append('file', audioBlob, 'audio.m4a')
    formData.append('model', 'gpt-4o-mini-transcribe') // half the price of whisper-1, same endpoint
    formData.append('language', 'en')

    console.log('Calling OpenAI Whisper API...')

    // Call OpenAI Whisper API
    const whisperResponse = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
      },
      body: formData
    })

    console.log('Whisper API status:', whisperResponse.status)

    if (!whisperResponse.ok) {
      const errorText = await whisperResponse.text()
      console.error('Whisper API error:', errorText)
      throw new Error(`Whisper API error (${whisperResponse.status}): ${errorText}`)
    }

    const result = await whisperResponse.json()
    console.log('Transcription successful, length:', result.text?.length || 0)

    return new Response(
      JSON.stringify({ text: result.text }),
      {
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        status: 200
      }
    )
  } catch (error) {
    console.error('=== ERROR ===')
    console.error('Error:', (error as Error).message)

    return new Response(
      JSON.stringify({
        error: (error as Error).message
      }),
      {
        headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})
