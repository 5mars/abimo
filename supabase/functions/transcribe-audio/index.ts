import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  serve(async (req) => {
    // Handle CORS preflight
    if (req.method === 'OPTIONS') {
      return new Response('ok', { headers: corsHeaders })
    }

      const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Not authenticated" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

    try {
      const { audioUrl } = await req.json()

      console.log('=== Whisper Transcription Started ===')
      console.log('Audio URL:', audioUrl)

      const apiKey = Deno.env.get('OPENAI_API_KEY')
      if (!apiKey) {
        throw new Error('OpenAI API key is not configured')
      }
      console.log('API Key present:', apiKey.substring(0, 10) + '...')

      // Download the audio file
      console.log('Downloading audio file...')
      const audioResponse = await fetch(audioUrl)
      console.log('Download status:', audioResponse.status)

      if (!audioResponse.ok) {
        throw new Error(`Failed to download audio: ${audioResponse.statusText}`)
      }

      const audioBlob = await audioResponse.blob()
      console.log('Audio downloaded, size:', audioBlob.size, 'bytes')

      // Create form data for Whisper API
      const formData = new FormData()
      formData.append('file', audioBlob, 'audio.m4a')
      formData.append('model', 'whisper-1')
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
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200
        }
      )
    } catch (error) {
      console.error('=== ERROR ===')
      console.error('Error:', error.message)

      return new Response(
        JSON.stringify({
          error: error.message
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 500
        }
      )
    }
  })
