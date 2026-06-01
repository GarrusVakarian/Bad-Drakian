import { useMemo, useState } from 'react';
import {
  Button,
  Collapsible,
  Icon,
  Input,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type OrbitTarget = {
  full_name: string;
  ref: string;
  orbiters?: number;
  job?: string;
};

type OrbitData = {
  alive: OrbitTarget[];
  dead: OrbitTarget[];
  ghosts: OrbitTarget[];
  misc: OrbitTarget[];
  npcs: OrbitTarget[];
  orbiting_ref?: string;
};

const SECTIONS = [
  { key: 'alive', title: 'Alive', color: 'blue' },
  { key: 'dead', title: 'Dead', color: 'average' },
  { key: 'ghosts', title: 'Ghosts', color: 'label' },
  { key: 'misc', title: 'Misc', color: 'average' },
  { key: 'npcs', title: 'NPCs', color: 'average' },
] as const;

function itemMatches(item: OrbitTarget, query: string) {
  if (!query) {
    return true;
  }
  const haystack = `${item.full_name} ${item.job || ''}`.toLowerCase();
  return haystack.includes(query);
}

export const Orbit = (props) => {
  const { act, data } = useBackend<OrbitData>();
  const [query, setQuery] = useState('');

  const normalizedQuery = query.trim().toLowerCase();

  const sections = useMemo(() => {
    return SECTIONS.map((section) => {
      const source = (data[section.key] || []) as OrbitTarget[];
      const filtered = source.filter((item) => itemMatches(item, normalizedQuery));
      return {
        ...section,
        items: filtered,
      };
    }).filter((section) => section.items.length > 0);
  }, [data, normalizedQuery]);

  return (
    <Window title="Orbit" width={460} height={560}>
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section>
              <Stack align="center">
                <Stack.Item>
                  <Icon name="search" />
                </Stack.Item>
                <Stack.Item grow>
                  <Input
                    autoFocus
                    fluid
                    placeholder="Search..."
                    value={query}
                    onChange={setQuery}
                  />
                </Stack.Item>
                <Stack.Item>
                  <Button icon="sync-alt" onClick={() => act('refresh')} tooltip="Refresh" />
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            <Section fill scrollable>
              {sections.length === 0 && (
                <NoticeBox>No orbit targets match your search.</NoticeBox>
              )}

              {sections.map((section) => (
                <Collapsible key={section.key} title={`${section.title} - (${section.items.length})`}>
                  <Stack wrap>
                    {section.items.map((item) => {
                      const selected = data.orbiting_ref === item.ref;
                      return (
                        <Stack.Item key={item.ref}>
                          <Button
                            color={section.color}
                            onClick={() => act('orbit', { ref: item.ref })}
                            selected={selected}
                            tooltip={item.job || item.full_name}
                            tooltipPosition="bottom-start"
                          >
                            <Stack>
                              <Stack.Item>{item.full_name}</Stack.Item>
                              {!!item.orbiters && (
                                <Stack.Item>
                                  <Icon name="ghost" /> {item.orbiters}
                                </Stack.Item>
                              )}
                            </Stack>
                          </Button>
                        </Stack.Item>
                      );
                    })}
                  </Stack>
                </Collapsible>
              ))}
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
