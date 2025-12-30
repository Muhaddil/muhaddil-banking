export async function fetchNui<T = any>(eventName: string, data?: any): Promise<T> {
  const options = {
    method: "post",
    headers: {
      "Content-Type": "application/json; charset=UTF-8",
    },
    body: JSON.stringify(data),
  }

  const resourceName = (window as any).GetParentResourceName
    ? (window as any).GetParentResourceName()
    : "muhaddil-banking"

  const resp = await fetch(`https://${resourceName}/${eventName}`, options)

  const text = await resp.text()
  if (!text) return {} as T

  try {
    return JSON.parse(text)
  } catch (e) {
    console.warn(`[fetchNui] Failed to parse JSON response for ${eventName}:`, text)
    return {} as T
  }
}
