import React, { useEffect, useRef, useState } from 'react';
import {
  Box,
  Button,
  Input,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  draft: string;
  preview_html: string;
  has_existing_text: boolean;
  signed: boolean;
  font: string;
  standard_font: string;
  fonts: string[];
  maxlen: number;
  needs_import_confirm: boolean;
};

export const PaperWriterPanel = () => {
  const { act, data } = useBackend<Data>();
  const {
    draft: initialDraft,
    preview_html,
    signed,
    font: backendFont,
    standard_font,
    fonts,
    maxlen,
    needs_import_confirm,
  } = data;

  const [draft, setDraft] = useState(initialDraft || '');
  const [font, setFont] = useState(backendFont || 'default');
  const [colorHex, setColorHex] = useState('862f20');
  const [previewDirty, setPreviewDirty] = useState(false);
  const draftInputRef = useRef<HTMLTextAreaElement | null>(null);

  useEffect(() => {
    setDraft(initialDraft || '');
  }, [initialDraft]);

  useEffect(() => {
    setFont(backendFont || 'default');
  }, [backendFont]);

  const pushDraft = (nextDraft: string, nextFont: string = font) => {
    setDraft(nextDraft);
    if (nextFont !== font) {
      setFont(nextFont);
    }
    setPreviewDirty(true);
  };

  const pushFont = (nextFont: string) => {
    setFont(nextFont);
    setPreviewDirty(true);
  };

  const updatePreview = () => {
    act('update_draft', { draft, font });
    setPreviewDirty(false);
  };

  useEffect(() => {
    if (!previewDirty) {
      return;
    }
    const handle = setTimeout(() => {
      act('update_draft', { draft, font });
      setPreviewDirty(false);
    }, 450);
    return () => clearTimeout(handle);
  }, [previewDirty, draft, font]);

  const insertToken = (startToken: string, endToken = '') => {
    const input = draftInputRef.current;
    if (!input) {
      pushDraft(`${draft}${startToken}${endToken}`);
      return;
    }

    const start = input.selectionStart ?? draft.length;
    const end = input.selectionEnd ?? draft.length;
    const selectedText = draft.slice(start, end);
    const nextDraft =
      draft.slice(0, start) +
      startToken +
      selectedText +
      endToken +
      draft.slice(end);

    pushDraft(nextDraft);

    requestAnimationFrame(() => {
      input.focus();
      const selectionStart = start + startToken.length;
      const selectionEnd = selectionStart + selectedText.length;
      if (selectedText.length > 0) {
        input.setSelectionRange(selectionStart, selectionEnd);
      } else {
        input.setSelectionRange(selectionStart, selectionStart);
      }
    });
  };

  const sanitizeColorHex = (value: string) => {
    const normalized = value.replace('#', '').trim().toUpperCase();
    return /^[0-9A-F]{6}$/.test(normalized) ? normalized : '862F20';
  };

  const insertColorBlock = (hexValue: string) => {
    const cleanHex = sanitizeColorHex(hexValue);
    setColorHex(cleanHex);
    insertToken(`-=${cleanHex}colored text=-`);
  };

  const remaining = Math.max(0, maxlen - draft.length);

  return (
    <Window width={760} height={680} title="Letter Editor">
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <Section title="Input (Append New Text)">
              <Stack mb={1} wrap>
                <Stack.Item>
                  <Button onClick={() => insertToken('**', '**')}>Bold</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertToken('*', '*')}>Italics</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertToken('# ')}>Header</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertToken('((', '))')}>Small</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertToken('\n---\n')}>Rule</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertToken('\n* item')}>Bullet List</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertToken('\n1. item')}>Numbered List</Button>
                </Stack.Item>
              </Stack>

              <Stack mb={1} wrap align="center">
                <Stack.Item>
                  <Box color="label">Color:</Box>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertColorBlock('862F20')}>Red Ink</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertColorBlock('14103F')}>Blue Ink</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertColorBlock('1A3A1A')}>Green</Button>
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertColorBlock('8B6914')}>Gold</Button>
                </Stack.Item>
                <Stack.Item grow>
                  <Input
                    value={colorHex}
                    onChange={(value) => setColorHex(value.toUpperCase())}
                    placeholder="RRGGBB"
                    fluid
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button onClick={() => insertColorBlock(colorHex)}>Insert Color</Button>
                </Stack.Item>
              </Stack>

              <Box mb={1}>
                <label>
                  Font:{' '}
                  <select
                    value={font}
                    onChange={(event) =>
                      pushFont((event.target as HTMLSelectElement).value)
                    }
                  >
                    {(fonts || []).map((fontName) => (
                      <option key={fontName} value={fontName}>
                        {fontName === 'default'
                          ? `Standard (${standard_font || 'legacy pen'})`
                          : fontName}
                      </option>
                    ))}
                  </select>
                </label>
              </Box>

              <Box mt={1} mb={1} color={remaining < 50 ? 'bad' : 'label'}>
                Draft characters: {draft.length}/{maxlen}
              </Box>
              <Box mb={1}>
                <Button
                  icon="sync"
                  color={previewDirty ? 'average' : undefined}
                  onClick={updatePreview}>
                  Update Preview
                </Button>
              </Box>
              <textarea
                ref={draftInputRef}
                style={{
                  height: '220px',
                  width: '100%',
                  resize: 'vertical',
                }}
                value={draft}
                onChange={(event) => pushDraft(event.target.value)}
                placeholder="Write text to append under the existing letter..."
              />
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Section title="Preview (Saved + Current Input)">
              <NoticeBox>
                No saved content yet. New writing is appended below previous text.
              </NoticeBox>
              {!!needs_import_confirm && (
                <NoticeBox danger mt={1}>
                  This letter was imported from existing formatted text. Saving may simplify older
                  formatting details. Use Save Anyway to confirm overwrite.
                </NoticeBox>
              )}
              <Box mt={1} mb={1} color={signed ? 'good' : 'label'}>
                Signature status: {signed ? 'Signed' : 'Unsigned'}
              </Box>
              <Box
                style={{
                  background: '#fdf6e3',
                  border: '1px solid #b8a27d',
                  minHeight: '250px',
                  padding: '10px',
                  fontFamily: 'serif',
                }}
                dangerouslySetInnerHTML={{ __html: preview_html || '' }}
              />
            </Section>
          </Stack.Item>

          <Stack.Item>
            <Stack>
              <Stack.Item>
                <Button
                  color="good"
                  icon="signature"
                  onClick={() => {
                    updatePreview();
                    act('sign');
                  }}>
                  Sign
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="average"
                  icon="eraser"
                  onClick={() => {
                    setDraft('');
                    act('clear');
                  }}>
                  Clear
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  color="bad"
                  icon="times"
                  onClick={() => act('close')}>
                  Close
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
