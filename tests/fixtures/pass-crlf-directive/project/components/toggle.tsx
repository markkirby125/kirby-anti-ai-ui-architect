"use client"

import { useState } from "react"

export function Toggle() {
  const [on, setOn] = useState(false)
  return <button onClick={() => setOn(!on)}>{on ? "On" : "Off"}</button>
}
