import { PageHeader } from "antd";
import React from "react";

// displays a page header

export default function Header() {
  return (
    <a href="https://Judiciary.app" target="_blank" rel="noopener noreferrer">
      <PageHeader title="⛰️ Judiciary" subTitle="Playground" style={{ cursor: "pointer" }} />
    </a>
  );
}
