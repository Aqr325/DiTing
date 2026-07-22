export function extractUrls(text: string): string[] {
  const urlPattern = new RegExp('https?:\\/\\/[^\\s<>"{}|\\\\^`[\\]]+', 'g')
  return text.match(urlPattern) || []
}
