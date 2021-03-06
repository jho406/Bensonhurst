import { JSDOM } from 'jsdom'
import { render } from 'react-dom'
import start from '../../../lib/index'
import fetchMock from 'fetch-mock'
import * as rsp from '../../fixtures'
import React from 'react'
import { mapStateToProps, mapDispatchToProps } from '../../../lib/utils/react'
import { Provider, connect } from 'react-redux'
import { createMemoryHistory } from 'history'
import configureMockStore from 'redux-mock-store'
import Nav from '../../../lib/components/NavComponent.js'

const createScene = (html) => {
  const dom = new JSDOM(`${html}`, { runScripts: 'dangerously' })
  return { dom, target: dom.window.document.body.firstElementChild }
}

class Home extends React.Component {
  constructor(props) {
    super(props)
    this.enhancedVisit = this.visit.bind(this)
  }

  visit() {
    this.props.navigateTo('/foo')
  }

  render() {
    return (
      <div>
        Home Page
        <button onClick={this.enhancedVisit}> click </button>
      </div>
    )
  }
}

class About extends React.Component {
  render() {
    return <h1>About Page</h1>
  }
}

describe('mapStateToToProps', () => {
  it('returns the state of the url and the csrfToken', () => {
    let dispatch = jasmine.createSpy('dispatch')
    let slice = {
      pages: {
        '/foo': {
          data: { heading: 'hi' },
          flash: {},
        },
      },
      breezy: {
        csrfToken: 'token123',
      },
    }

    let props = mapStateToProps(slice, { pageKey: '/foo' })
    expect(props).toEqual({
      heading: 'hi',
      pageKey: '/foo',
      csrfToken: 'token123',
      flash: {},
    })
  })
})
